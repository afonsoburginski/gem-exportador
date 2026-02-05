# Conexão ODBC - GemExportador

## Dados para configurar no ODBC

| Campo | Valor |
|-------|-------|
| **Driver** | SQLite3 ODBC Driver |
| **DSN** | GemExportador |
| **Database** | `\\192.168.1.43\gem-exportador\database\gem-exportador.db` |
| **User** | *(vazio)* |
| **Password** | *(vazio)* |

---

## Download do Driver

http://www.ch-werner.de/sqliteodbc/

Instalar: `sqliteodbc_w64.exe` (Windows 64-bit)

---

## Tabela: `desenho`

### Campos obrigatórios para INSERT

| Campo | Tipo | Exemplo |
|-------|------|---------|
| id | TEXT | UUID gerado automaticamente |
| nome_arquivo | TEXT | `170000112_03.idw` |
| computador | TEXT | `ESTACAO01` |
| caminho_destino | TEXT | `\\servidor\pasta\destino` |
| status | TEXT | `pendente` |
| arquivo_original | TEXT | `\\servidor\desenhos\arquivo.idw` |
| formatos_solicitados | TEXT | `["PDF","DWG","DWF"]` |
| horario_envio | TEXT | `2026-02-04T15:30:00` |
| horario_atualizacao | TEXT | `2026-02-04T15:30:00` |
| criado_em | TEXT | `2026-02-04T15:30:00` |
| atualizado_em | TEXT | `2026-02-04T15:30:00` |

### Valores de status

- `pendente` - Aguardando processamento
- `processando` - Em processamento
- `concluido` - Finalizado com sucesso
- `erro` - Falhou
- `cancelado` - Cancelado pelo usuário

---

## Exemplo de INSERT

```sql
INSERT INTO desenho (
    id,
    nome_arquivo,
    computador,
    caminho_destino,
    status,
    arquivo_original,
    formatos_solicitados,
    horario_envio,
    horario_atualizacao,
    progresso,
    tentativas,
    arquivos_enviados_para_usuario,
    criado_em,
    atualizado_em
) VALUES (
    lower(hex(randomblob(16))),
    'NOME_ARQUIVO.idw',
    'NOME_COMPUTADOR',
    '\\servidor\pasta\destino',
    'pendente',
    '\\servidor\desenhos\NOME_ARQUIVO.idw',
    '["PDF","DWG","DWF"]',
    datetime('now'),
    datetime('now'),
    0,
    0,
    0,
    datetime('now'),
    datetime('now')
);
```
