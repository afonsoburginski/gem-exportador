# GEM Exportador

Sistema de exportação automática de arquivos do Autodesk Inventor para múltiplos formatos (PDF, DWG, DXF, STEP, etc).

## Visão Geral

O GEM Exportador é uma aplicação multiplataforma que automatiza a conversão de arquivos do Autodesk Inventor. Usuários enviam arquivos através de uma macro VBA integrada ao Inventor, e o sistema processa os arquivos em background, gerando os formatos solicitados.

### Arquitetura

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Inventor      │     │    Servidor     │     │   App Desktop   │
│   (Macro VBA)   │───▶ │   (Ktor HTTP)   |◀───│   (Compose)     │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
                        ┌────────▼────────┐
                        │     SQLite      │
                        │   (Banco Local) │
                        └─────────────────┘
```

## Tecnologias

| Componente | Tecnologia | Versão |
|------------|------------|--------|
| Linguagem | Kotlin | 1.9.21 |
| JDK | Java | 17 |
| Build | Gradle | 8.2.1 |
| UI Desktop | Compose Multiplatform | 1.5.11 |
| HTTP Server | Ktor | 2.3.7 |
| Banco de Dados | SQLite + SQLDelight | 2.0.1 |
| Coroutines | Kotlinx Coroutines | 1.7.3 |
| Serialização | Kotlinx Serialization | 1.6.2 |

## Estrutura do Projeto

```
gem-exportador/
├── desktopApp/          # Aplicação Desktop (Windows)
├── shared/              # Código compartilhado (UI, Banco, Models)
├── server/              # Servidor HTTP embutido (Ktor)
├── androidApp/          # App Android (futuro)
├── iosApp/              # App iOS (futuro)
├── scripts/             # Scripts VBS e Macros do Inventor
├── macro-usuario/       # Macro VBA para usuários do Inventor
└── mcp-sqlite/          # Servidor MCP para acesso ao SQLite
```

## Funcionalidades

### 1. Envio de Arquivos (Macro VBA)
- Integração direta com Autodesk Inventor
- Seleção de formatos de saída (PDF, DWG, DXF, STEP, IGES, etc)
- Escolha da pasta de destino
- Envio via HTTP para o servidor

### 2. Processamento Automático
- Fila de processamento com prioridade
- Conversão em background usando API do Inventor
- Suporte a múltiplos formatos simultaneamente
- Retry automático em caso de falha

### 3. Interface Desktop
- Visualização em tempo real da fila
- Status de cada arquivo (pendente, processando, concluído, erro)
- Progresso de conversão por formato
- Ações: cancelar, reenviar, abrir pasta

### 4. Sincronização em Tempo Real (WebSocket)
- Atualização instantânea da UI quando dados mudam
- Similar ao Supabase Realtime
- Reconexão automática em caso de queda

### 5. Auto-Update
- Verificação automática de novas versões no GitHub
- Download e instalação em background
- Suporte a instalador NSIS (.exe)

---

## Banco de Dados

### Localização
```
C:\gem-exportador\database\gem-exportador.db
```

### Tabela: `desenho`

```sql
CREATE TABLE desenho (
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

CREATE INDEX idx_desenho_status ON desenho(status);
CREATE INDEX idx_desenho_computador ON desenho(computador);
CREATE INDEX idx_desenho_horario_envio ON desenho(horario_envio);
```

### Valores de Status

| Status | Descrição |
|--------|-----------|
| `pendente` | Aguardando processamento |
| `processando` | Em processamento |
| `concluido` | Finalizado com sucesso |
| `erro` | Falhou |
| `cancelado` | Cancelado pelo usuário |
| `concluido_com_erros` | Parcialmente concluído |

---

## API REST

### Base URL
```
http://{IP}:8080
```

### Endpoints

#### Desenhos

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/desenhos` | Lista todos os desenhos |
| GET | `/desenhos/{id}` | Busca por ID |
| POST | `/desenhos` | Cria novo desenho |
| PUT | `/desenhos/{id}` | Atualiza desenho |
| PATCH | `/desenhos/{id}/status` | Atualiza status |
| DELETE | `/desenhos/{id}` | Remove desenho |

#### Outros

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/health` | Health check |
| GET | `/stats` | Estatísticas |
| GET | `/queue` | Fila de processamento |

### Exemplo de Payload (POST /desenhos)

```json
{
  "nomeArquivo": "Peca_001.ipt",
  "computador": "PC-ENGENHARIA-01",
  "caminhoDestino": "C:\\Projetos\\Exportados",
  "formatosSolicitados": ["pdf", "dwg", "dxf"],
  "arquivoOriginal": "C:\\Projetos\\Origem\\Peca_001.ipt"
}
```

---

## WebSocket (Realtime)

### Endpoint
```
ws://{IP}:8080/ws
```

### Fluxo de Conexão

1. Cliente conecta no WebSocket
2. Cliente envia: `{"type":"subscribe","table":"desenhos"}`
3. Servidor envia dados iniciais: `{"type":"initial","data":[...]}`
4. Servidor envia eventos conforme mudanças ocorrem

### Tipos de Mensagem

#### Dados Iniciais
```json
{
  "type": "initial",
  "data": [{ "id": "...", "nomeArquivo": "...", ... }]
}
```

#### Insert
```json
{
  "type": "INSERT",
  "data": { "id": "...", "nomeArquivo": "...", ... }
}
```

#### Update
```json
{
  "type": "UPDATE",
  "data": { "id": "...", "status": "processando", "progresso": 45, ... }
}
```

#### Delete
```json
{
  "type": "DELETE",
  "id": "uuid-do-registro"
}
```

### Exemplo (JavaScript)

```javascript
const ws = new WebSocket('ws://192.168.1.66:8080/ws');

ws.onopen = () => {
  ws.send(JSON.stringify({type: 'subscribe', table: 'desenhos'}));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  
  switch(msg.type) {
    case 'initial':
      console.log('Dados iniciais:', msg.data);
      break;
    case 'INSERT':
      console.log('Novo:', msg.data);
      break;
    case 'UPDATE':
      console.log('Atualizado:', msg.data);
      break;
    case 'DELETE':
      console.log('Removido:', msg.id);
      break;
  }
};
```

---

## Conexão ODBC

### Pré-requisitos
1. Instalar driver: [SQLite ODBC Driver](http://www.ch-werner.de/sqliteodbc/)
2. Baixar: `sqliteodbc_w64.exe` (64-bit)

### Configuração

| Campo | Valor |
|-------|-------|
| Data Source Name | `GEM-exportador` |
| Database Name | `C:\gem-exportador\database\gem-exportador.db` |

### Acesso via Rede
```
\\{IP}\gem-exportador\database\gem-exportador.db
```

---

## Instalação

### Requisitos
- Windows 10/11
- Autodesk Inventor 2020+ (para processamento)
- JDK 17+ (apenas para desenvolvimento)

### Instalação do App

1. Baixe o instalador da [página de releases](https://github.com/afonsoburginski/gem-exportador/releases)
2. Execute `GemExportador-X.X.X-setup.exe`
3. Siga o assistente de instalação

### Arquivos Criados

```
C:\Program Files\GemExportador\    # Aplicação
C:\gem-exportador\database\        # Banco de dados
C:\gem-exportador\logs\            # Logs
C:\gem-exportador\controle\        # Arquivos de controle
```

---

## Desenvolvimento

### Build

```bash
# Compilar
./gradlew desktopApp:compileKotlinJvm

# Executar em dev
./gradlew desktopApp:run

# Gerar instalador NSIS
./gradlew buildNsisInstaller
```

### Estrutura de Código

```
shared/src/
├── commonMain/kotlin/
│   ├── App.kt                    # Entry point Compose
│   ├── model/                    # Data classes
│   ├── data/                     # Repository, RealtimeClient
│   └── ui/components/            # Componentes UI
├── desktopMain/kotlin/
│   ├── main.desktop.kt           # Platform-specific
│   ├── config/DesktopConfig.kt   # Configurações
│   └── util/                     # UpdateChecker, etc
└── commonMain/sqldelight/        # Schema do banco
```

### Release

1. Atualizar versão em `gradle.properties`
2. Commit e push
3. Criar tag: `git tag vX.X.X && git push origin vX.X.X`
4. GitHub Actions gera o release automaticamente

---

## Configuração (.env)

Arquivo criado automaticamente na instalação em `C:\Program Files\GemExportador\.env`:

```env
SERVER_HOST=127.0.0.1
SERVER_PORT=8080
SERVER_URL=http://localhost:8080
INVENTOR_PASTA_CONTROLE=C:\gem-exportador\controle
DATABASE_DIR=C:\gem-exportador\database
LOG_LEVEL=INFO
LOG_DIR=C:\gem-exportador\logs
```

---

## Logs

### Localização
```
C:\gem-exportador\logs\gem-exportador.log
C:\gem-exportador\logs\gem-exportador-desktop.log
```

### Níveis
- `DEBUG` - Detalhes técnicos
- `INFO` - Operações normais
- `WARN` - Avisos
- `ERROR` - Erros

---

## Licença

Projeto proprietário - Todos os direitos reservados.

---

## Contato

Para suporte ou dúvidas, entre em contato com a equipe de desenvolvimento.
