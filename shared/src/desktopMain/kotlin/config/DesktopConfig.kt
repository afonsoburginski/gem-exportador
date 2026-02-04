package config

import io.github.cdimascio.dotenv.dotenv
import java.io.File

/**
 * Configuração do desktop lida do .env (na raiz do projeto ou diretório de execução).
 */
object DesktopConfig {
    private val envDir: String by lazy {
        val candidates = listOf(
            File(System.getProperty("user.dir")),
            File(System.getProperty("user.dir")).parentFile,
            File(System.getProperty("user.dir"), ".."),
            File(System.getProperty("user.dir"), "../..")
        )
        candidates.firstOrNull { it != null && File(it, ".env").exists() }?.absolutePath
            ?: System.getProperty("user.dir")
    }

    private val dotenv by lazy {
        dotenv {
            directory = envDir
            ignoreIfMissing = true
        }
    }

    val serverUrl: String? get() {
        val url = get("SERVER_URL", "http://localhost:8080")
        return url.ifBlank { null }
    }

    /** Pasta do banco de dados SQLite (padrão: ./database) */
    val databaseDir: File get() {
        val path = get("DATABASE_DIR", "")
        return if (path.isNotBlank()) File(path) else File(System.getProperty("user.dir"), "database")
    }

    /** Pasta dos logs (padrão: ./logs) */
    val logDir: File get() {
        val path = get("LOG_DIR", "")
        return if (path.isNotBlank()) File(path) else File(System.getProperty("user.dir"), "logs")
    }

    private fun get(key: String, default: String): String {
        return dotenv[key]?.ifBlank { null } ?: System.getenv(key)?.ifBlank { null } ?: default
    }
}
