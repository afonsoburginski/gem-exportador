package util

import config.DesktopConfig
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * No desktop grava em LOG_DIR/gem-exportador-desktop.log (padrão: ./logs/).
 */
actual fun logToFile(level: String, message: String) {
    val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS").withZone(ZoneId.systemDefault())
    val line = "${formatter.format(Instant.now())} [$level] $message"
    // Sempre imprime no console
    println(line)
    // Também grava em arquivo
    try {
        val logDir = DesktopConfig.logDir.apply { mkdirs() }
        val logFile = File(logDir, "gem-exportador-desktop.log")
        synchronized(AppLogDesktop) {
            logFile.appendText("$line\n")
        }
    } catch (e: Exception) {
        System.err.println(line)
    }
}

private object AppLogDesktop
