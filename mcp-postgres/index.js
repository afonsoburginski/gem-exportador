#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import pg from "pg";
import { z } from "zod";

const { Pool } = pg;

// Configurações do PostgreSQL (usa variáveis de ambiente ou padrão)
const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT || "5432"),
  database: process.env.DB_NAME || "gem_exportador",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
});

// Testa a conexão
try {
  await pool.query("SELECT 1");
  console.error(`Conectado ao PostgreSQL: ${process.env.DB_HOST || "localhost"}:${process.env.DB_PORT || "5432"}/${process.env.DB_NAME || "gem_exportador"}`);
} catch (err) {
  console.error(`Erro ao conectar ao PostgreSQL: ${err.message}`);
  process.exit(1);
}

const server = new McpServer({
  name: "gem-exportador-postgres",
  version: "1.0.0",
});

// Tool: Listar tabelas
server.tool("list_tables", "Lista todas as tabelas do banco de dados", {}, async () => {
  const result = await pool.query(`
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    ORDER BY table_name
  `);
  return {
    content: [{ type: "text", text: JSON.stringify(result.rows.map(t => t.table_name), null, 2) }]
  };
});

// Tool: Descrever tabela (schema)
server.tool("describe_table", "Mostra a estrutura de uma tabela", {
  table: z.string().describe("Nome da tabela")
}, async ({ table }) => {
  const result = await pool.query(`
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns 
    WHERE table_name = $1 
    ORDER BY ordinal_position
  `, [table]);
  return {
    content: [{ type: "text", text: JSON.stringify(result.rows, null, 2) }]
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
    const result = await pool.query(sql);
    return {
      content: [{ type: "text", text: JSON.stringify(result.rows, null, 2) }]
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
    const result = await pool.query(sql);
    return {
      content: [{ type: "text", text: JSON.stringify({ rowCount: result.rowCount }, null, 2) }]
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
  let params = [];
  if (status) {
    sql = "SELECT id, nome_arquivo, status, progresso, formatos_solicitados, arquivos_processados FROM desenho WHERE status = $1 ORDER BY horario_envio DESC";
    params = [status];
  }
  const result = await pool.query(sql, params);
  return {
    content: [{ type: "text", text: JSON.stringify(result.rows, null, 2) }]
  };
});

// Tool: Ver desenho específico
server.tool("ver_desenho", "Mostra detalhes de um desenho específico", {
  id: z.string().describe("ID do desenho")
}, async ({ id }) => {
  const result = await pool.query("SELECT * FROM desenho WHERE id = $1", [id]);
  if (result.rows.length === 0) {
    return {
      content: [{ type: "text", text: "Desenho não encontrado" }],
      isError: true
    };
  }
  return {
    content: [{ type: "text", text: JSON.stringify(result.rows[0], null, 2) }]
  };
});

// Tool: Atualizar status de um desenho
server.tool("atualizar_status", "Atualiza o status de um desenho", {
  id: z.string().describe("ID do desenho"),
  status: z.enum(["pendente", "processando", "concluido", "erro", "cancelado"]).describe("Novo status")
}, async ({ id, status }) => {
  const now = new Date().toISOString();
  const result = await pool.query(
    "UPDATE desenho SET status = $1, horario_atualizacao = $2, atualizado_em = $2 WHERE id = $3",
    [status, now, id]
  );
  if (result.rowCount === 0) {
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
  const tablesResult = await pool.query(`
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    ORDER BY table_name
  `);
  const counts = {};
  for (const t of tablesResult.rows) {
    const countResult = await pool.query(`SELECT COUNT(*) as count FROM "${t.table_name}"`);
    counts[t.table_name] = parseInt(countResult.rows[0].count);
  }
  return {
    contents: [{
      uri: "database://info",
      mimeType: "application/json",
      text: JSON.stringify({ 
        type: "PostgreSQL",
        host: process.env.DB_HOST || "localhost",
        port: process.env.DB_PORT || "5432",
        database: process.env.DB_NAME || "gem_exportador",
        tables: counts 
      }, null, 2)
    }]
  };
});

// Inicia o servidor
const transport = new StdioServerTransport();
await server.connect(transport);
