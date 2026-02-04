package data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.jhonrob.gemexportador.db.GemDatabase
import config.DesktopConfig
import java.io.File

actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        // Usa pasta configurada no .env (DATABASE_DIR) ou ./database
        val dbDir = DesktopConfig.databaseDir.apply { mkdirs() }
        val databasePath = File(dbDir, "gem-exportador.db")
        val databaseExists = databasePath.exists()
        
        val driver = JdbcSqliteDriver("jdbc:sqlite:${databasePath.absolutePath}")
        
        // Só cria as tabelas se o banco não existia
        if (!databaseExists) {
            GemDatabase.Schema.create(driver)
        }
        
        return driver
    }

    companion object {
        fun getDatabasePath(): String {
            val dbDir = DesktopConfig.databaseDir
            return File(dbDir, "gem-exportador.db").absolutePath
        }
    }
}
