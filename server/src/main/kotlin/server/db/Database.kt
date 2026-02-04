package server.db

import server.config.Config
import java.io.File
import java.sql.Connection
import java.sql.DriverManager

/**
 * SQLite JDBC para o servidor (schema compatível com shared/desktop).
 * Banco fica em DATABASE_DIR/gem-exportador.db (padrão: ./database/)
 */
class Database {
    private val dbDir = Config.databaseDir.apply { mkdirs() }
    private val dbFile = File(dbDir, "gem-exportador.db")
    private val jdbcUrl = "jdbc:sqlite:${dbFile.absolutePath}"

    fun getDatabasePath(): String = dbFile.absolutePath

    fun connection(): Connection = DriverManager.getConnection(jdbcUrl)

    fun init() {
        connection().use { conn ->
            conn.createStatement().executeUpdate("""
                CREATE TABLE IF NOT EXISTS desenho (
                    id TEXT NOT NULL PRIMARY KEY,
                    nome_arquivo TEXT NOT NULL,
                    computador TEXT NOT NULL,
                    caminho_destino TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pendente',
                    posicao_fila INTEGER,
                    horario_envio TEXT NOT NULL,
                    horario_atualizacao TEXT NOT NULL,
                    formatos_solicitados TEXT,
                    arquivo_original TEXT,
                    arquivos_processados TEXT,
                    erro TEXT,
                    progresso INTEGER NOT NULL DEFAULT 0,
                    tentativas INTEGER NOT NULL DEFAULT 0,
                    arquivos_enviados_para_usuario INTEGER NOT NULL DEFAULT 0,
                    cancelado_em TEXT,
                    criado_em TEXT NOT NULL,
                    atualizado_em TEXT NOT NULL,
                    pasta_processamento TEXT
                );
            """.trimIndent())
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_status ON desenho(status);")
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_computador ON desenho(computador);")
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_horario_envio ON desenho(horario_envio);")
        }
    }
}
