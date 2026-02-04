# Servidor Gem Exportador (Kotlin + Ktor)

Backend com a mesma lógica do app antigo (jhonrob-desenhos): APIs REST + WebSocket para a tabela atualizar em tempo real via SQLite local no desktop.

## Como rodar

```bash
./gradlew :server:run
# ou
./gradlew :server:run --args=""
```

Servidor sobe em **http://localhost:8080**.

## Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/health` | Health check |
| GET | `/api/desenhos` | Lista desenhos (query: status, computador, limit, offset) |
| POST | `/api/desenhos/upload` | Upload multipart (arquivo + nomeArquivo, computador, caminhoDestino, formatos) |
| GET | `/api/desenhos/{id}` | Detalhe do desenho |
| PATCH | `/api/desenhos/{id}` | Atualiza desenho (body: status, progresso, arquivosProcessados, erro) |
| POST | `/api/desenhos/{id}/cancelar` | Cancela processamento |
| POST | `/api/desenhos/{id}/retry` | Reenfileira (só formatos faltantes) |
| GET | `/api/desenhos/{id}/download/{tipo}` | Download do arquivo processado (pdf, dwg, etc.) |
| POST | `/api/explorador` | Abre explorador no caminho (body: `{ "caminho": "C:\\pasta" }`) |
| GET | `/api/queue` | Status da fila |
| GET | `/api/stats` | Estatísticas (total, por status, por computador) |
| WebSocket | `/ws` | Sincronização em tempo real: envia `initial`, `INSERT`, `UPDATE`, `DELETE` |

## Banco e dados

- SQLite em `data/gem-exportador.db` (criado na pasta de execução).
- Arquivos de upload em `processados/{id}/`.

## Processamento Inventor (Windows)

O servidor usa o script **`processar-inventor.vbs`** para enviar o trabalho ao Inventor. Quem faz a parte pesada é o **Autodesk Inventor** com o **`MacroServidor.bas`** rodando dentro dele.

1. **Servidor (Ktor)** – para cada item da fila chama:
   ```text
   cscript //Nologo scripts\processar-inventor.vbs "arquivoEntrada" "pastaSaida" "formato" "pastaControle"
   ```
2. **processar-inventor.vbs** – escreve `comando.txt` na pasta de controle (linha: `entrada|saida|formato`) e grava em `%APPDATA%\JhonRob\jhonrob_controle_pasta.txt` (e `C:\jhonrob_controle_pasta.txt`) o caminho dessa pasta para o macro.
3. **MacroServidor.bas** (dentro do Inventor) – lê a pasta de controle, quando aparece `comando.txt` processa e grava `sucesso.txt` ou `erro.txt`. O VBS espera por isso e retorna.

**Requisitos:**

- Windows (o runner só executa o VBS no Windows).
- Script em `gem-exportador/scripts/processar-inventor.vbs` (ou `server/../scripts/`).
- Inventor aberto com o macro **IniciarServicoSilencioso** (ou **IniciarServico**) em execução.

**Pasta de controle:** por padrão `data/controle` (relativa ao diretório de execução). Para usar outra (ex.: pasta em rede acessível pelo Inventor), defina a variável de ambiente **`INVENTOR_PASTA_CONTROLE`**.

## Desktop + servidor

1. Inicie o servidor: `./gradlew :server:run`
2. Inicie o desktop: `./gradlew :desktopApp:run`

O desktop usa por padrão `http://localhost:8080`: conecta ao WebSocket em `ws://localhost:8080/ws`, recebe `initial` e depois `INSERT`/`UPDATE`/`DELETE`, e grava tudo no SQLite local. A tabela reage sozinha às mudanças. As ações **Reenviar** e **Cancelar** chamam a API do servidor; o servidor atualiza o banco e faz broadcast, e o cliente atualiza o SQLite local.
