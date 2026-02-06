package server.db

import server.config.Config
import server.util.AppLog
import java.sql.Connection
import java.sql.DriverManager

/**
 * PostgreSQL JDBC para o servidor.
 * Conecta ao PostgreSQL local (instalado pelo setup-postgres.cmd durante a instalação).
 * Configuração via variáveis de ambiente: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
 */
class Database {
    private val jdbcUrl = Config.jdbcUrl
    private val user = Config.dbUser
    private val password = Config.dbPassword

    fun connection(): Connection = DriverManager.getConnection(jdbcUrl, user, password)

    fun init() {
        AppLog.info("Conectando ao PostgreSQL: ${Config.dbHost}:${Config.dbPort}/${Config.dbName}")
        
        // Retry de conexão (PostgreSQL pode estar iniciando)
        var lastError: Exception? = null
        repeat(10) { attempt ->
            try {
                connection().use { conn ->
                    conn.createStatement().executeUpdate("""
                        CREATE TABLE IF NOT EXISTS desenho (
                            id TEXT NOT NULL PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
                            nome_arquivo TEXT NOT NULL,
                            computador TEXT NOT NULL DEFAULT '',
                            caminho_destino TEXT NOT NULL DEFAULT '',
                            status TEXT NOT NULL DEFAULT 'pendente',
                            posicao_fila INTEGER,
                            horario_envio TIMESTAMPTZ NOT NULL DEFAULT now(),
                            horario_atualizacao TIMESTAMPTZ NOT NULL DEFAULT now(),
                            formatos_solicitados TEXT,
                            arquivo_original TEXT,
                            arquivos_processados TEXT,
                            erro TEXT,
                            progresso INTEGER DEFAULT 0,
                            tentativas INTEGER NOT NULL DEFAULT 0,
                            arquivos_enviados_para_usuario INTEGER DEFAULT 0,
                            cancelado_em TIMESTAMPTZ,
                            criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
                            atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
                            pasta_processamento TEXT
                        )
                    """.trimIndent())
                    
                    // Cria índices
                    conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_status ON desenho(status)")
                    conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_computador ON desenho(computador)")
                    conn.createStatement().executeUpdate("CREATE INDEX IF NOT EXISTS idx_desenho_horario_envio ON desenho(horario_envio)")
                    
                    // Trigger para notificações em tempo real (LISTEN/NOTIFY)
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
                    
                    conn.createStatement().executeUpdate("DROP TRIGGER IF EXISTS desenho_changes_trigger ON desenho")
                    conn.createStatement().executeUpdate("""
                        CREATE TRIGGER desenho_changes_trigger
                        AFTER INSERT OR UPDATE OR DELETE ON desenho
                        FOR EACH ROW EXECUTE FUNCTION notify_desenho_changes()
                    """.trimIndent())
                    
                    AppLog.info("PostgreSQL inicializado com sucesso!")
                    return
                }
            } catch (e: Exception) {
                lastError = e
                AppLog.info("Tentativa ${attempt + 1}/10 de conexão falhou, aguardando...")
                Thread.sleep(2000)
            }
        }
        
        throw RuntimeException("Não foi possível conectar ao PostgreSQL após 10 tentativas: ${lastError?.message}", lastError)
    }
}
