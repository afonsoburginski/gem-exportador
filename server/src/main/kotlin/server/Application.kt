package server

import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.util.*
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import model.DesenhoAutodesk
import server.broadcast.Broadcast
import server.db.Database
import server.db.DesenhoDao
import server.queue.ProcessingQueue
import server.routes.*
import server.util.AppLog

fun Application.configureSerialization() {
    install(io.ktor.server.plugins.contentnegotiation.ContentNegotiation) {
        json(Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        })
    }
}

fun Application.configureStatusPages() {
    install(io.ktor.server.plugins.statuspages.StatusPages) {
        exception<Throwable> { call, cause ->
            AppLog.error("Exceção não tratada: ${cause.message}", cause)
            call.respond(io.ktor.http.HttpStatusCode.InternalServerError, mapOf(
                "erro" to (cause.message ?: "Erro interno")
            ))
        }
    }
}

/*
 * ========== SEED DE TESTE (DESABILITADO PARA PRODUÇÃO) ==========
 * Para habilitar em desenvolvimento, descomente a chamada seedDatabase(desenhoDao) em configureRouting()
 * 
 * private fun seedDatabase(desenhoDao: DesenhoDao) {
 *     desenhoDao.deleteAll()
 *     val unico = DesenhoAutodesk(
 *         id = "6489ad02-603a-4608-b777-86a526afd438",
 *         nomeArquivo = "170000112_03.idw",
 *         computador = "SRVMTGEM1",
 *         caminhoDestino = "\\\\srvmtgem1\\Arquivos\$\\DESENHOS GERENCIADOR\\170",
 *         status = "pendente",
 *         posicaoFila = 1,
 *         horarioEnvio = "2026-01-29 17:01:30",
 *         horarioAtualizacao = "2026-01-29 17:01:30",
 *         formatosSolicitadosJson = """["pdf","dwf","dwg"]""",
 *         arquivoOriginal = "\\\\srvmtgem1\\Arquivos\$\\desenhos gerenciador 3D\\170\\170000112_03.idw",
 *         arquivosProcessadosJson = "[]",
 *         erro = null,
 *         progresso = 0,
 *         tentativas = 0,
 *         arquivosEnviadosParaUsuario = 0,
 *         canceladoEm = null,
 *         criadoEm = "2026-01-29 17:01:30",
 *         atualizadoEm = "2026-01-29 17:01:30",
 *         pastaProcessamento = null
 *     )
 *     desenhoDao.insert(unico)
 *     AppLog.info("Base seedada com 1 registro em pendente (170000112_03.idw)")
 * }
 * ================================================================
 */

@OptIn(InternalAPI::class)
fun Application.configureRouting() {
    val db = Database()
    db.init()
    val desenhoDao = DesenhoDao(db)
    
    // PRODUÇÃO: Não faz seed, usa dados reais do banco
    AppLog.info("Servidor gem-exportador iniciando em PRODUCAO; base de dados em data/gem-exportador.db")
    // Para desenvolvimento/teste, descomente: seedDatabase(desenhoDao)
    
    val broadcast = Broadcast()
    val queue = ProcessingQueue(desenhoDao, broadcast)
    
    // Adiciona desenhos pendentes à fila automaticamente na inicialização
    kotlinx.coroutines.runBlocking {
        val pendentes = desenhoDao.list(status = "pendente", limit = 100, offset = 0)
        if (pendentes.isNotEmpty()) {
            AppLog.info("Adicionando ${pendentes.size} desenho(s) pendente(s) a fila...")
            for (desenho in pendentes) {
                queue.add(desenho.id)
                AppLog.info("  -> ${desenho.nomeArquivo} adicionado a fila")
            }
        }
    }
    
    // REALTIME: Monitora mudanças no arquivo do banco (como Supabase)
    startDatabaseWatcher(db, desenhoDao, queue, broadcast)

    routing {
        apiHealth()
        apiDesenhos(desenhoDao, queue, broadcast)
        apiExplorador()
        apiQueue(queue)
        apiStats(desenhoDao)
    }
}

fun Application.configureWebSocket() {
    install(WebSockets) {
        pingPeriod = java.time.Duration.ofSeconds(15)
        timeout = java.time.Duration.ofSeconds(15)
        maxFrameSize = Long.MAX_VALUE
        masking = false
    }
}

/**
 * REALTIME DATABASE WATCHER
 * Monitora o arquivo do banco SQLite para detectar mudanças externas (via ODBC).
 * Similar ao realtime do Supabase - detecta INSERT/UPDATE quase instantaneamente.
 */
private fun startDatabaseWatcher(
    db: Database,
    desenhoDao: DesenhoDao,
    queue: ProcessingQueue,
    broadcast: Broadcast
) {
    val dbPath = java.nio.file.Paths.get(db.getDatabasePath())
    val dbDir = dbPath.parent
    val dbFileName = dbPath.fileName.toString()
    
    // Cache do estado atual para detectar mudanças
    val estadoConhecido = java.util.concurrent.ConcurrentHashMap<String, String>() // id -> status+atualizado_em
    
    // Carrega estado inicial
    desenhoDao.list(limit = 10000, offset = 0).forEach { d ->
        estadoConhecido[d.id] = "${d.status}|${d.atualizadoEm}"
    }
    
    kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
        AppLog.info("Realtime watcher iniciado: monitorando $dbPath")
        
        try {
            val watchService = java.nio.file.FileSystems.getDefault().newWatchService()
            dbDir.register(
                watchService,
                java.nio.file.StandardWatchEventKinds.ENTRY_MODIFY
            )
            
            var ultimaVerificacao = System.currentTimeMillis()
            
            while (true) {
                // Aguarda evento de modificação no diretório (timeout 500ms para não travar)
                val key = watchService.poll(500, java.util.concurrent.TimeUnit.MILLISECONDS)
                
                if (key != null) {
                    for (event in key.pollEvents()) {
                        val fileName = event.context()?.toString() ?: continue
                        // Verifica se é o arquivo do banco ou WAL
                        if (fileName == dbFileName || fileName.startsWith(dbFileName)) {
                            val agora = System.currentTimeMillis()
                            // Debounce: só processa se passou 100ms desde última verificação
                            if (agora - ultimaVerificacao > 100) {
                                ultimaVerificacao = agora
                                verificarMudancas(desenhoDao, queue, broadcast, estadoConhecido)
                            }
                        }
                    }
                    key.reset()
                }
            }
        } catch (e: Exception) {
            AppLog.error("Erro no watcher, usando fallback polling: ${e.message}")
            // Fallback: polling a cada 500ms se watcher falhar
            while (true) {
                kotlinx.coroutines.delay(500)
                try {
                    verificarMudancas(desenhoDao, queue, broadcast, estadoConhecido)
                } catch (e: Exception) {
                    AppLog.error("Erro no polling: ${e.message}")
                }
            }
        }
    }
}

private suspend fun verificarMudancas(
    desenhoDao: DesenhoDao,
    queue: ProcessingQueue,
    broadcast: Broadcast,
    estadoConhecido: java.util.concurrent.ConcurrentHashMap<String, String>
) {
    val todos = desenhoDao.list(limit = 10000, offset = 0)
    
    for (desenho in todos) {
        val estadoAtual = "${desenho.status}|${desenho.atualizadoEm}"
        val estadoAnterior = estadoConhecido[desenho.id]
        
        if (estadoAnterior == null) {
            // NOVO REGISTRO
            estadoConhecido[desenho.id] = estadoAtual
            AppLog.info("[REALTIME] Novo registro: ${desenho.nomeArquivo}")
            broadcast.sendInsert(desenho)
            if (desenho.status == "pendente") {
                queue.add(desenho.id)
                AppLog.info("[REALTIME] -> Adicionado à fila de processamento")
            }
        } else if (estadoAnterior != estadoAtual) {
            // REGISTRO ATUALIZADO EXTERNAMENTE
            estadoConhecido[desenho.id] = estadoAtual
            AppLog.info("[REALTIME] Atualização externa: ${desenho.nomeArquivo} -> ${desenho.status}")
            broadcast.sendUpdate(desenho)
        }
    }
}
