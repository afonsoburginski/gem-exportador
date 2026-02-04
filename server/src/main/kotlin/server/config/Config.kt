package server.config

import io.github.cdimascio.dotenv.Dotenv
import io.github.cdimascio.dotenv.dotenv
import java.io.File

/**
 * Configuração do servidor lida do .env (na raiz do projeto ou diretório de execução).
 */
object Config {
    private val dotenv: Dotenv = dotenv {
        directory = findEnvDirectory()
        ignoreIfMissing = true
    }

    val serverHost: String get() = get("SERVER_HOST", "0.0.0.0")
    val serverPort: Int get() = get("SERVER_PORT", "8080").toIntOrNull() ?: 8080
    val serverUrl: String get() = get("SERVER_URL", "http://localhost:8080")
    val inventorPastaControle: String? get() = get("INVENTOR_PASTA_CONTROLE", "").ifBlank { null }
    val logLevel: String get() = get("LOG_LEVEL", "INFO")

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

    private fun findEnvDirectory(): String {
        val candidates = listOf(
            File(System.getProperty("user.dir")),
            File(System.getProperty("user.dir")).parentFile,
            File(System.getProperty("user.dir"), ".."),
            File(System.getProperty("user.dir"), "../..")
        )
        for (dir in candidates) {
            if (File(dir, ".env").exists()) return dir.absolutePath
        }
        return System.getProperty("user.dir")
    }
}
