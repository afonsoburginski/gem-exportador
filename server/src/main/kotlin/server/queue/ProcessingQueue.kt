package server.queue

import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import model.ArquivoProcessado
import model.DesenhoAutodesk
import server.broadcast.Broadcast
import server.db.DesenhoDao
import server.inventor.InventorRunner
import server.util.AppLog
import java.io.File

/**
 * Fila de processamento (um item = desenhoId + formato).
 * O servidor chama processar-inventor.vbs; o VBS escreve comando.txt e o MacroServidor.bas
 * (rodando dentro do Inventor) faz o processamento pesado e grava sucesso.txt/erro.txt.
 */
class ProcessingQueue(
    private val desenhoDao: DesenhoDao,
    private val broadcast: Broadcast
) {
    private val json = Json { ignoreUnknownKeys = true }
    data class Item(val desenhoId: String, val formato: String, val posicaoFila: Int, val tentativa: Int = 1)

    companion object {
        /** Máximo de tentativas automáticas por formato */
        const val MAX_TENTATIVAS = 3
        /** Delay (ms) entre tentativas para o Inventor se recuperar */
        const val DELAY_RETRY_MS = 15_000L // 15 segundos
    }

    private val queue = mutableListOf<Item>()
    private val mutex = Mutex()
    private var processing = false
    private var currentItem: Item? = null
    private var processorJob: Job? = null

    init {
        processorJob = CoroutineScope(Dispatchers.Default).launch {
            processLoop()
        }
    }

    suspend fun add(desenhoId: String, formatosOverride: List<String>? = null) {
        val desenho = desenhoDao.getById(desenhoId) ?: return
        val formatos = formatosOverride?.map { it.trim().lowercase() }?.filter { it.isNotEmpty() }
            ?: desenho.formatosSolicitados.ifEmpty { listOf("pdf") }
        val pos = desenhoDao.countPendentesEProcessando()
        mutex.withLock {
            formatos.forEach { f ->
                if (!queue.any { it.desenhoId == desenhoId && it.formato == f })
                    queue.add(Item(desenhoId, f, desenho.posicaoFila ?: pos))
            }
            queue.sortWith(compareBy({ it.posicaoFila }, { it.desenhoId }, { it.formato }))
        }
        // Não precisa chamar processLoop() - já roda no init via CoroutineScope
    }

    fun remove(desenhoId: String): Boolean {
        var removed = false
        runBlocking {
            mutex.withLock {
                val before = queue.size
                queue.removeAll { it.desenhoId == desenhoId }
                removed = queue.size < before
            }
        }
        return removed
    }

    fun getStatus(): Map<String, Any?> = runBlocking {
        mutex.withLock {
            mapOf<String, Any?>(
                "tamanho" to queue.size,
                "processando" to processing,
                "processoAtual" to currentItem?.let { "${it.desenhoId} (${it.formato}) tentativa ${it.tentativa}" },
                "processoAtualDetalhe" to currentItem?.let { mapOf("desenhoId" to it.desenhoId, "formato" to it.formato, "tentativa" to it.tentativa) },
                "proximos" to queue.take(10).map { "pos${it.posicaoFila} ${it.desenhoId}:${it.formato} t${it.tentativa}" },
                "proximosItens" to queue.take(50).map { mapOf("desenhoId" to it.desenhoId, "formato" to it.formato, "posicaoFila" to it.posicaoFila, "tentativa" to it.tentativa) }
            )
        }
    }

    private suspend fun processLoop() {
        while (true) {
            val item = mutex.withLock {
                if (queue.isEmpty()) {
                    processing = false
                    currentItem = null
                    null
                } else {
                    processing = true
                    currentItem = queue.first()
                    queue.removeAt(0)
                    currentItem
                }
            }
            if (item == null) {
                delay(1000)
                continue
            }

            var desenho = desenhoDao.getById(item.desenhoId)
            if (desenho == null || desenho.status == "cancelado") {
                currentItem = null
                continue
            }

            desenhoDao.update(item.desenhoId, status = "processando")
            broadcast.sendUpdate(desenhoDao.getById(item.desenhoId)!!)
            val tentativaInfo = if (item.tentativa > 1) " [tentativa ${item.tentativa}/$MAX_TENTATIVAS]" else ""
            AppLog.info("Processando desenho ${item.desenhoId} formato ${item.formato}$tentativaInfo (entrada: ${desenho.nomeArquivo})")

            val arquivoEntrada = InventorRunner.resolverArquivoEntrada(
                desenho.arquivoOriginal,
                desenho.pastaProcessamento,
                desenho.nomeArquivo
            )
            if (arquivoEntrada.isEmpty() || !File(arquivoEntrada).exists()) {
                val msg = "Arquivo original não encontrado: ${desenho.arquivoOriginal}"
                AppLog.warn("$msg [desenho=${item.desenhoId}]")
                desenhoDao.update(item.desenhoId, status = "erro", erro = msg)
                broadcast.sendUpdate(desenhoDao.getById(item.desenhoId)!!)
                currentItem = null
                continue
            }

            val pastaSaida = InventorRunner.destinoParaExportados(desenho.caminhoDestino)
            val pastaControle = InventorRunner.pastaControle()

            val result = withContext(Dispatchers.IO) {
                InventorRunner.run(arquivoEntrada, pastaSaida, item.formato, pastaControle)
            }

            desenho = desenhoDao.getById(item.desenhoId)!!
            if (desenho.status == "cancelado") {
                currentItem = null
                continue
            }

            val existentes = desenho.arquivosProcessados.toMutableList()
            val formatosSolicitados = desenho.formatosSolicitados.ifEmpty { listOf("pdf") }
            
            // Rastrear formatos com erro
            val errosAnteriores = desenho.erro?.split(";")?.filter { it.isNotBlank() }?.toMutableList() ?: mutableListOf()
            
            if (result.success && result.arquivoGerado != null) {
                AppLog.info("Formato ${item.formato} concluído para ${item.desenhoId}: ${result.arquivoGerado}")
                val novo = ArquivoProcessado(
                    nome = File(result.arquivoGerado).name,
                    tipo = item.formato,
                    caminho = result.arquivoGerado,
                    tamanho = File(result.arquivoGerado).length()
                )
                existentes.removeAll { it.tipo.equals(item.formato, ignoreCase = true) }
                existentes.add(novo)
                // Remove erro deste formato se existia
                errosAnteriores.removeAll { it.startsWith("${item.formato}:") }
            } else {
                val errMsg = result.errorMessage ?: "Erro no processamento"
                AppLog.error("Erro ao processar ${item.desenhoId} formato ${item.formato} (tentativa ${item.tentativa}/${MAX_TENTATIVAS}): $errMsg")

                // Auto-retry: re-adicionar à fila se não esgotou tentativas
                if (item.tentativa < MAX_TENTATIVAS) {
                    val proxTentativa = item.tentativa + 1
                    AppLog.info("[AUTO-RETRY] Reagendando ${desenho.nomeArquivo} formato ${item.formato} -> tentativa $proxTentativa/$MAX_TENTATIVAS (aguardando ${DELAY_RETRY_MS / 1000}s)")
                    // Delay para o Inventor se recuperar
                    delay(DELAY_RETRY_MS)
                    mutex.withLock {
                        queue.add(Item(item.desenhoId, item.formato, item.posicaoFila, proxTentativa))
                    }
                    // Não registra erro ainda — só quando esgotar tentativas
                    // Atualiza status para processando e continua
                    desenhoDao.update(item.desenhoId, status = "processando")
                    broadcast.sendUpdate(desenhoDao.getById(item.desenhoId)!!)
                    currentItem = null
                    continue
                }

                // Esgotou tentativas — registra erro definitivo
                AppLog.error("[AUTO-RETRY] ${desenho.nomeArquivo} formato ${item.formato} FALHOU após $MAX_TENTATIVAS tentativas")
                errosAnteriores.removeAll { it.startsWith("${item.formato}:") }
                errosAnteriores.add("${item.formato}: falhou após ${MAX_TENTATIVAS} tentativas")
            }
            
            // Calcula progresso: conta formatos concluídos com sucesso
            val totalFormatos = formatosSolicitados.size
            val concluidos = formatosSolicitados.count { fmt ->
                existentes.any { it.tipo.equals(fmt, ignoreCase = true) }
            }
            
            // Verifica se ainda há formatos pendentes na fila para este desenho
            val formatosPendentes = mutex.withLock {
                queue.filter { it.desenhoId == item.desenhoId }.map { it.formato }
            }
            val todoProcessado = formatosPendentes.isEmpty()
            
            // Se TODOS os formatos foram concluídos com sucesso, limpa erros antigos (retry resolveu)
            if (concluidos >= totalFormatos && todoProcessado) {
                errosAnteriores.clear()
            }

            // Determina status final
            val novoStatus = when {
                !todoProcessado -> "processando" // Ainda há formatos na fila
                errosAnteriores.isEmpty() && concluidos >= totalFormatos -> "concluido"
                errosAnteriores.isNotEmpty() && concluidos > 0 -> "concluido_com_erros"
                errosAnteriores.isNotEmpty() -> "erro"
                else -> "processando"
            }
            
            val progresso = if (totalFormatos == 0) 100 else (100 * concluidos / totalFormatos).coerceIn(0, 100)
            
            desenhoDao.update(
                item.desenhoId,
                status = novoStatus,
                progresso = progresso,
                arquivosProcessados = json.encodeToString(existentes),
                erro = if (errosAnteriores.isEmpty()) null else errosAnteriores.joinToString("; ")
            )
            val updated = desenhoDao.getById(item.desenhoId)
            if (updated != null) broadcast.sendUpdate(updated)
            currentItem = null
        }
    }
}
