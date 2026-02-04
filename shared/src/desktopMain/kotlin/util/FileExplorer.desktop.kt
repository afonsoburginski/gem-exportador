package util

import java.awt.Desktop
import java.io.File

/**
 * Abre uma pasta no explorador de arquivos (Windows/Mac/Linux)
 */
actual fun openInExplorer(path: String) {
    try {
        val trimmed = path.trim()
        if (trimmed.isEmpty()) return

        val os = System.getProperty("os.name").lowercase()

        if (os.contains("win")) {
            // Windows: explorer.exe aceita UNC (\\servidor\pasta) e caminhos locais
            val pathParaExplorer = trimmed.replace("/", "\\")
            ProcessBuilder("explorer.exe", pathParaExplorer).start()
            return
        }

        if (os.contains("mac")) {
            Runtime.getRuntime().exec(arrayOf("open", trimmed))
            return
        }

        // Linux e outros
        val file = File(trimmed)
        if (Desktop.isDesktopSupported()) {
            val desktop = Desktop.getDesktop()
            if (file.exists()) {
                desktop.open(file)
            } else {
                val parent = file.parentFile
                if (parent?.exists() == true) desktop.open(parent)
            }
        } else {
            Runtime.getRuntime().exec(arrayOf("xdg-open", trimmed))
        }
    } catch (e: Exception) {
        println("Erro ao abrir explorador: ${e.message}")
    }
}
