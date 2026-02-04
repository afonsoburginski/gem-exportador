package util

/**
 * Log da aplicação. No desktop grava em arquivo; em outras plataformas pode ser no-op ou console.
 */
expect fun logToFile(level: String, message: String)
