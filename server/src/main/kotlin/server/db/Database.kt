package server.db

import server.config.Config
import server.util.AppLog
import java.sql.Connection
import java.sql.DriverManager

/**
 * PostgreSQL JDBC para o servidor.
 * Configuração via variáveis de ambiente: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
 */
class Database {
    private val jdbcUrl = Config.jdbcUrl
    private val user = Config.dbUser
    private val password = Config.dbPassword

    fun connection(): Connection = DriverManager.getConnection(jdbcUrl, user, password)

    fun init() {
        AppLog.info("Conectando ao PostgreSQL: ${Config.dbHost}:${Config.dbPort}/${Config.dbName}")
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
                )
            """.trimIndent())
            
            // Cria índices (PostgreSQL usa CREATE INDEX IF NOT EXISTS)
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_status ON desenho(status)")
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_computador ON desenho(computador)")
            conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_horario_envio ON desenho(horario_envio)")
            
            // Cria função e trigger para notificações em tempo real
            conn.createStatement().executeUpdate("""
                CREATE OR REPLACE FUNCTION notify_desenho_changes()
                RETURNS TRIGGER AS $$
                BEGIN
                    IF TG_OP = 'INSERT' THEN
                        PERFORM pg_notify('desenho_changes', json_build_object('op', 'INSERT', 'id', NEW.id)::text);
                    ELSIF TG_OP = 'UPDATE' THEN
                        PERFORM pg_notify('desenho_changes', json_build_object('op', 'UPDATE', 'id', NEW.id)::text);
                    ELSIF TG_OP = 'DELETE' THEN
                        PERFORM pg_notify('desenho_changes', json_build_object('op', 'DELETE', 'id', OLD.id)::text);
                    END IF;
                    RETURN COALESCE(NEW, OLD);
                END;
                $$ LANGUAGE plpgsql
            """.trimIndent())
            
            // Remove trigger existente e recria
            conn.createStatement().executeUpdate("DROP TRIGGER IF EXISTS desenho_changes_trigger ON desenho")
            conn.createStatement().executeUpdate("""
                CREATE TRIGGER desenho_changes_trigger
                AFTER INSERT OR UPDATE OR DELETE ON desenho
                FOR EACH ROW EXECUTE FUNCTION notify_desenho_changes()
            """.trimIndent())
            
            AppLog.info("PostgreSQL inicializado com sucesso!")
        }
    }
}
