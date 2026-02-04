package data

import app.cash.sqldelight.db.SqlDriver

/**
 * Factory para criar o driver do banco de dados
 * Implementação específica por plataforma
 */
expect class DatabaseDriverFactory {
    fun createDriver(): SqlDriver
}
