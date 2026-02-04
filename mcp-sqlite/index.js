#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import Database from "better-sqlite3";
import { z } from "zod";

// Caminho do banco de dados (usa variável de ambiente ou padrão)
const DB_PATH = process.env.GEM_SQLITE_PATH || "C:\\gem-exportador\\database\\gem-exportador.db";

let db;
try {
  db = new Database(DB_PATH, { readonly: false });
  db.pragma("journal_mode = WAL");
} catch (err) {
  console.error(`Erro ao abrir banco: ${err.message}`);
  process.exit(1);
}

const server = new McpServer({
  name: "gem-exportador-sqlite",
  version: "1.0.0",
});

// Tool: Listar tabelas
server.tool("list_tables", "Lista todas as tabelas do banco de dados", {}, async () => {
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all();
  return {
    content: [{ type: "text", text: JSON.stringify(tables.map(t => t.name), null, 2) }]
  };
});

// Tool: Descrever tabela (schema)
server.tool("describe_table", "Mostra a estrutura de uma tabela", {
  table: z.string().describe("Nome da tabela")
}, async ({ table }) => {
  const info = db.prepare(`PRAGMA table_info("${table}")`).all();
  return {
    content: [{ type: "text", text: JSON.stringify(info, null, 2) }]
  };
});

// Tool: Executar SELECT
server.tool("query", "Executa uma query SELECT no banco", {
  sql: z.string().describe("Query SQL (apenas SELECT)")
}, async ({ sql }) => {
  const sqlLower = sql.trim().toLowerCase();
  if (!sqlLower.startsWith("select")) {
    return {
      content: [{ type: "text", text: "Erro: Apenas queries SELECT são permitidas. Use 'execute' para INSERT/UPDATE/DELETE." }],
      isError: true
    };
  }
  try {
    const rows = db.prepare(sql).all();
    return {
      content: [{ type: "text", text: JSON.stringify(rows, null, 2) }]
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Erro: ${err.message}` }],
      isError: true
    };
  }
});

// Tool: Executar INSERT/UPDATE/DELETE
server.tool("execute", "Executa INSERT, UPDATE ou DELETE no banco", {
  sql: z.string().describe("Query SQL (INSERT, UPDATE ou DELETE)")
}, async ({ sql }) => {
  const sqlLower = sql.trim().toLowerCase();
  if (sqlLower.startsWith("select")) {
    return {
      content: [{ type: "text", text: "Erro: Use 'query' para SELECT." }],
      isError: true
    };
  }
  if (sqlLower.startsWith("drop") || sqlLower.startsWith("alter") || sqlLower.startsWith("create")) {
    return {
      content: [{ type: "text", text: "Erro: DROP, ALTER e CREATE não são permitidos." }],
      isError: true
    };
  }
  try {
    const result = db.prepare(sql).run();
    return {
      content: [{ type: "text", text: JSON.stringify({ changes: result.changes, lastInsertRowid: result.lastInsertRowid }, null, 2) }]
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Erro: ${err.message}` }],
      isError: true
    };
  }
});

// Tool: Listar desenhos
server.tool("listar_desenhos", "Lista todos os desenhos na fila", {
  status: z.string().optional().describe("Filtrar por status (pendente, processando, concluido, erro, cancelado)")
}, async ({ status }) => {
  let sql = "SELECT id, nome_arquivo, status, progresso, formatos_solicitados, arquivos_processados FROM desenho ORDER BY horario_envio DESC";
  if (status) {
    sql = `SELECT id, nome_arquivo, status, progresso, formatos_solicitados, arquivos_processados FROM desenho WHERE status = '${status}' ORDER BY horario_envio DESC`;
  }
  const rows = db.prepare(sql).all();
  return {
    content: [{ type: "text", text: JSON.stringify(rows, null, 2) }]
  };
});

// Tool: Ver desenho específico
server.tool("ver_desenho", "Mostra detalhes de um desenho específico", {
  id: z.string().describe("ID do desenho")
}, async ({ id }) => {
  const row = db.prepare("SELECT * FROM desenho WHERE id = ?").get(id);
  if (!row) {
    return {
      content: [{ type: "text", text: "Desenho não encontrado" }],
      isError: true
    };
  }
  return {
    content: [{ type: "text", text: JSON.stringify(row, null, 2) }]
  };
});

// Tool: Atualizar status de um desenho
server.tool("atualizar_status", "Atualiza o status de um desenho", {
  id: z.string().describe("ID do desenho"),
  status: z.enum(["pendente", "processando", "concluido", "erro", "cancelado"]).describe("Novo status")
}, async ({ id, status }) => {
  const now = new Date().toISOString();
  const result = db.prepare("UPDATE desenho SET status = ?, horario_atualizacao = ?, atualizado_em = ? WHERE id = ?").run(status, now, now, id);
  if (result.changes === 0) {
    return {
      content: [{ type: "text", text: "Desenho não encontrado" }],
      isError: true
    };
  }
  return {
    content: [{ type: "text", text: `Status atualizado para '${status}'` }]
  };
});

// Resource: Banco de dados info
server.resource("database://info", "database://info", async () => {
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all();
  const counts = {};
  for (const t of tables) {
    const row = db.prepare(`SELECT COUNT(*) as count FROM "${t.name}"`).get();
    counts[t.name] = row.count;
  }
  return {
    contents: [{
      uri: "database://info",
      mimeType: "application/json",
      text: JSON.stringify({ path: DB_PATH, tables: counts }, null, 2)
    }]
  };
});

// Inicia o servidor
const transport = new StdioServerTransport();
await server.connect(transport);
