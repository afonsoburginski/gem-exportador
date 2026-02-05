-- Schema PostgreSQL para o gem-exportador
-- Execute este arquivo para criar o banco de dados inicial

-- Cria o banco (execute como superuser se necessário)
-- CREATE DATABASE gem_exportador;

-- Tabela principal de desenhos
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

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_desenho_status ON desenho(status);
CREATE INDEX IF NOT EXISTS idx_desenho_computador ON desenho(computador);
CREATE INDEX IF NOT EXISTS idx_desenho_horario_envio ON desenho(horario_envio);

-- Função para notificações em tempo real (LISTEN/NOTIFY)
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
$$ LANGUAGE plpgsql;

-- Trigger para notificações automáticas
DROP TRIGGER IF EXISTS desenho_changes_trigger ON desenho;
CREATE TRIGGER desenho_changes_trigger
AFTER INSERT OR UPDATE OR DELETE ON desenho
FOR EACH ROW EXECUTE FUNCTION notify_desenho_changes();
