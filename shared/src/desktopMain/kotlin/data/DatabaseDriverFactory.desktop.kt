package data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.JdbcDriver
import com.jhonrob.gemexportador.db.GemDatabase
import config.DesktopConfig
import java.sql.DriverManager

actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        // Conecta ao PostgreSQL usando as configurações do .env
        val connection = DriverManager.getConnection(
            DesktopConfig.jdbcUrl,
            DesktopConfig.dbUser,
            DesktopConfig.dbPassword
        )
        
        val driver = object : JdbcDriver() {
            override fun getConnection() = connection
            override fun closeConnection(connection: java.sql.Connection) {
                // Não fecha a conexão aqui, mantém aberta para reutilização
            }
            override fun addListener(vararg queryKeys: String, listener: app.cash.sqldelight.Query.Listener) {}
            override fun removeListener(vararg queryKeys: String, listener: app.cash.sqldelight.Query.Listener) {}
            override fun notifyListeners(vararg queryKeys: String) {}
        }
        
        // Verifica se a tabela existe, se não, cria o schema
        try {
            connection.createStatement().executeQuery("SELECT 1 FROM desenho LIMIT 1")
        } catch (e: Exception) {
            GemDatabase.Schema.create(driver)
        }
        
        return driver
    }

    companion object {
        fun getConnectionInfo(): String {
            return "${DesktopConfig.dbHost}:${DesktopConfig.dbPort}/${DesktopConfig.dbName}"
        }
    }
}
