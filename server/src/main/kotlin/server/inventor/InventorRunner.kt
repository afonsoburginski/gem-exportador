package server.inventor

import server.config.Config
import server.util.AppLog
import java.io.File

/**
 * Executa o script processar-inventor.vbs para um único formato.
 * O VBS escreve comando.txt na pasta de controle; o MacroServidor.bas (rodando dentro do Inventor)
 * lê o comando, processa e grava sucesso.txt ou erro.txt.
 */
object InventorRunner {

    private const val VBS_NAME = "processar-inventor.vbs"
    private const val TIMEOUT_MINUTES = 25

    fun isWindows(): Boolean =
        System.getProperty("os.name").lowercase().contains("windows")

    /**
     * Localiza o script processar-inventor.vbs (em scripts/ na raiz do projeto ou em server/../scripts).
     */
    fun findScriptPath(): File? {
        val userDir = File(System.getProperty("user.dir"))
        val candidates = listOf(
            File(userDir, "scripts/$VBS_NAME"),
            File(userDir, "../scripts/$VBS_NAME"),
            File(userDir.parentFile, "scripts/$VBS_NAME"),
            File(userDir, "../../scripts/$VBS_NAME")
        )
        return candidates.firstOrNull { it.isFile }
    }

    /**
     * Pasta onde o VBS escreve comando.txt e o macro Inventor lê (jhonrob_controle_pasta.txt).
     * Lê de INVENTOR_PASTA_CONTROLE no .env ou variável de ambiente; senão usa ./data/controle.
     */
    fun pastaControle(): File {
        val fromConfig = Config.inventorPastaControle
        if (fromConfig != null) return File(fromConfig.replace("/", File.separator)).also { it.mkdirs() }
        val userDir = File(System.getProperty("user.dir"))
        return File(userDir, "data/controle").also { it.mkdirs() }
    }

    /**
     * Destino dos exportados: substitui "desenhos gerenciador 3d" por "DESENHOS GERENCIADOR".
     */
    fun destinoParaExportados(caminhoDestino: String): String {
        if (caminhoDestino.isBlank()) return caminhoDestino
        return caminhoDestino.replace(Regex("""desenhos\s+gerenciador\s+3d""", RegexOption.IGNORE_CASE), "DESENHOS GERENCIADOR")
    }

    /**
     * Resolve o arquivo de entrada: se arquivoOriginal for absoluto e existir, usa; senão tenta pastaProcessamento + nome.
     */
    fun resolverArquivoEntrada(arquivoOriginal: String?, pastaProcessamento: String?, nomeArquivo: String): String {
        val raw = (arquivoOriginal ?: "").trim()
        if (raw.isNotEmpty()) {
            val f = File(raw.replace("/", File.separator))
            if (f.exists()) return f.absolutePath
        }
        val base = pastaProcessamento?.trim()?.takeIf { it.isNotEmpty() } ?: return ""
        val nome = nomeArquivo.trim().ifEmpty { return "" }
        val candidato = File(base, nome)
        if (candidato.exists()) return candidato.absolutePath
        val nomeSemExt = nome.substringBeforeLast(".")
        for (ext in listOf(".ipt", ".iam", ".idw")) {
            val alt = File(base, nomeSemExt + ext)
            if (alt.exists()) return alt.absolutePath
        }
        return candidato.absolutePath
    }

    data class Result(
        val success: Boolean,
        val arquivoGerado: String?, // caminho absoluto do arquivo gerado
        val errorMessage: String?
    )

    /**
     * Executa cscript processar-inventor.vbs para um formato.
     * Bloqueia até o VBS terminar (o VBS por sua vez espera o macro Inventor gravar sucesso.txt ou erro.txt).
     */
    fun run(
        arquivoEntrada: String,
        pastaSaida: String,
        formato: String,
        pastaControle: File
    ): Result {
        if (!isWindows()) {
            AppLog.warn("InventorRunner: processamento só disponível no Windows")
            return Result(false, null, "Processamento Inventor só disponível no Windows")
        }
        val script = findScriptPath()
        if (script == null || !script.exists()) {
            AppLog.error("Script processar-inventor.vbs não encontrado")
            return Result(
                false,
                null,
                "Script processar-inventor.vbs não encontrado. Procurou em: ${listOf(File(System.getProperty("user.dir"), "scripts/$VBS_NAME").absolutePath)}"
            )
        }
        // Normaliza o caminho: preserva UNC (\\servidor), remove barras duplicadas no meio
        var pastaSaidaNorm = pastaSaida.replace("/", "\\")
        
        // Verifica se é caminho UNC (começa com \\)
        val isUnc = pastaSaidaNorm.startsWith("\\\\")
        if (isUnc) {
            // Remove o prefixo UNC temporariamente
            pastaSaidaNorm = pastaSaidaNorm.substring(2)
        }
        
        // Remove barras duplicadas no meio do caminho
        while (pastaSaidaNorm.contains("\\\\")) {
            pastaSaidaNorm = pastaSaidaNorm.replace("\\\\", "\\")
        }
        
        // Restaura o prefixo UNC se necessário
        if (isUnc) {
            pastaSaidaNorm = "\\\\$pastaSaidaNorm"
        }
        
        // Remove barra final (o VBS vai adicionar se necessário)
        while (pastaSaidaNorm.endsWith("\\")) {
            pastaSaidaNorm = pastaSaidaNorm.dropLast(1)
        }
        val formatoNorm = formato.trim().lowercase()
        val controlePath = pastaControle.absolutePath

        val pb = ProcessBuilder(
            "cscript",
            "//Nologo",
            script.absolutePath,
            arquivoEntrada,
            pastaSaidaNorm,
            formatoNorm,
            controlePath
        )
        pb.redirectErrorStream(false)
        pb.directory(script.parentFile)
        AppLog.info("Executando VBS: ${script.absolutePath} entrada=$arquivoEntrada saida=$pastaSaidaNorm formato=$formatoNorm")
        val process = pb.start()
        val stderr = process.errorStream.bufferedReader().readText()
        val stdout = process.inputStream.bufferedReader().readText()
        val finished = process.waitFor(TIMEOUT_MINUTES.toLong(), java.util.concurrent.TimeUnit.MINUTES)
        if (!finished) {
            process.destroyForcibly()
            AppLog.error("Timeout Inventor: processamento excedeu $TIMEOUT_MINUTES minutos. stderr: $stderr")
            return Result(false, null, "Timeout: processamento excedeu $TIMEOUT_MINUTES minutos. $stderr")
        }
        if (process.exitValue() != 0) {
            val msg = (stderr.ifBlank { stdout }).trim().take(500)
            AppLog.error("VBS retornou código ${process.exitValue()}: $msg")
            return Result(false, null, "Script VBS retornou erro (código ${process.exitValue()}): $msg")
        }
        val nomeBase = File(arquivoEntrada).nameWithoutExtension
        val arquivoEsperado = File(pastaSaidaNorm.trim(), "$nomeBase.$formatoNorm")
        val caminhoReal = if (arquivoEsperado.exists()) arquivoEsperado.absolutePath else null
        return Result(true, caminhoReal, null)
    }
}
