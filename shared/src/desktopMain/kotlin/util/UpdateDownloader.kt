package util

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.URL

/**
 * Gerencia o download e instalação de atualizações
 */
object UpdateDownloader {
    
    /**
     * Estado do download
     */
    sealed class DownloadState {
        object Idle : DownloadState()
        data class Downloading(val progress: Int) : DownloadState()
        data class Downloaded(val file: File) : DownloadState()
        data class Error(val message: String) : DownloadState()
        object Installing : DownloadState()
    }
    
    /**
     * Baixa o arquivo da URL especificada
     * @param url URL do arquivo para download
     * @param onProgress Callback com progresso (0-100)
     * @return Arquivo baixado ou null em caso de erro
     */
    suspend fun downloadUpdate(
        url: String,
        onProgress: (Int) -> Unit = {}
    ): File? = withContext(Dispatchers.IO) {
        try {
            val tempDir = File(System.getProperty("java.io.tmpdir"), "gem-exportador-update")
            tempDir.mkdirs()
            
            val fileName = url.substringAfterLast("/").ifEmpty { "GemExportador-setup.exe" }
            val outputFile = File(tempDir, fileName)
            
            // Se já existe um arquivo com mesmo nome, remove
            if (outputFile.exists()) {
                outputFile.delete()
            }
            
            println("[UPDATE] Baixando de: $url")
            println("[UPDATE] Salvando em: ${outputFile.absolutePath}")
            
            val connection = URL(url).openConnection()
            connection.setRequestProperty("User-Agent", "GemExportador/${AppVersion.current}")
            connection.connectTimeout = 30_000
            connection.readTimeout = 120_000
            
            val contentLength = connection.contentLengthLong
            var downloaded = 0L
            
            connection.getInputStream().use { input ->
                FileOutputStream(outputFile).use { output ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloaded += bytesRead
                        
                        if (contentLength > 0) {
                            val progress = ((downloaded * 100) / contentLength).toInt()
                            onProgress(progress)
                        }
                    }
                }
            }
            
            println("[UPDATE] Download concluído: ${outputFile.length()} bytes")
            onProgress(100)
            outputFile
            
        } catch (e: Exception) {
            println("[UPDATE] Erro no download: ${e.message}")
            e.printStackTrace()
            null
        }
    }
    
    /**
     * Executa o instalador (suporta .exe do NSIS e .msi legado).
     * 
     * Para NSIS (.exe): cria um script batch auxiliar que aguarda o app fechar
     * e então lança o instalador via "start" para lidar corretamente com
     * UAC elevation (RequestExecutionLevel admin). O ProcessBuilder direto
     * falha com CreateProcess error=740 para .exe que requerem admin.
     * 
     * @param installerFile Arquivo do instalador
     * @return true se o instalador foi iniciado com sucesso
     */
    fun installUpdate(installerFile: File): Boolean {
        return try {
            if (!installerFile.exists()) {
                println("[UPDATE] Arquivo do instalador não encontrado: ${installerFile.absolutePath}")
                return false
            }
            
            println("[UPDATE] Preparando instalador: ${installerFile.absolutePath} (${installerFile.length()} bytes)")
            
            // Desbloqueia o arquivo (Windows pode bloquear downloads da internet)
            try {
                ProcessBuilder("powershell", "-Command",
                    "Unblock-File -Path '${installerFile.absolutePath}' -ErrorAction SilentlyContinue")
                    .redirectErrorStream(true).start().waitFor()
                println("[UPDATE] Arquivo desbloqueado")
            } catch (e: Exception) {
                println("[UPDATE] Aviso: não foi possível desbloquear arquivo: ${e.message}")
            }
            
            if (installerFile.name.endsWith(".msi")) {
                // Instalador MSI legado
                ProcessBuilder(
                    "msiexec", "/i", installerFile.absolutePath, "/passive", "/norestart"
                ).start()
                println("[UPDATE] MSI iniciado")
            } else {
                // Instalador NSIS (.exe) - NÃO podemos usar ProcessBuilder direto
                // porque o .exe requer admin (RequestExecutionLevel admin no NSIS)
                // e ProcessBuilder falha com "CreateProcess error=740".
                //
                // Solução: criar um batch auxiliar que usa "start" do cmd.exe,
                // que corretamente dispara o prompt UAC do Windows.
                // O timeout de 2s garante que o app Java já fechou quando o
                // instalador iniciar (evita conflito de arquivos).
                val batchFile = File(installerFile.parentFile, "gem-run-update.cmd")
                batchFile.writeText(
                    "@echo off\r\n" +
                    "timeout /t 2 /nobreak >NUL\r\n" +
                    "start \"GemExportador Update\" \"${installerFile.absolutePath}\" /S\r\n" +
                    "del \"%~f0\"\r\n" // batch se auto-deleta
                )
                
                ProcessBuilder("cmd", "/c", batchFile.absolutePath)
                    .redirectErrorStream(true)
                    .directory(installerFile.parentFile)
                    .start()
                    
                println("[UPDATE] Batch de atualização iniciado: ${batchFile.absolutePath}")
            }
            
            true
            
        } catch (e: Exception) {
            println("[UPDATE] Erro ao iniciar instalador: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    /**
     * Limpa arquivos de atualização antigos
     */
    fun cleanupOldUpdates() {
        try {
            val tempDir = File(System.getProperty("java.io.tmpdir"), "gem-exportador-update")
            if (tempDir.exists()) {
                tempDir.listFiles()?.forEach { file ->
                    // Remove arquivos com mais de 7 dias
                    val ageMs = System.currentTimeMillis() - file.lastModified()
                    val ageDays = ageMs / (1000 * 60 * 60 * 24)
                    if (ageDays > 7) {
                        file.delete()
                        println("[UPDATE] Removido arquivo antigo: ${file.name}")
                    }
                }
            }
        } catch (e: Exception) {
            // Ignora erros de limpeza
        }
    }
}
