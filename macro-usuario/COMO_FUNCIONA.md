# 📘 Como Funciona o Sistema de Exportação de Desenhos

## 🎯 Visão Geral

Sistema que permite exportar arquivos do Autodesk Inventor (PC do usuário) para processamento no servidor. O servidor (potente) recebe o arquivo ORIGINAL, processa e exporta os formatos solicitados (PDF, DWG, DWF).

---

## 🏗️ Arquitetura

### Componentes

1. **Cliente (PC do Usuário)**
   - Autodesk Inventor com macros VBA
   - Envia arquivo ORIGINAL (.ipt, .iam, .idw) para servidor
   - Exporta CSV e DXF localmente (não envia ao servidor)

2. **Servidor (Potente)**
   - API Node.js/Bun
   - Recebe arquivo em `uploads/` (temporário)
   - Move para `processados/{id}/` (permanente)
   - Processa com Autodesk Inventor do servidor
   - Exporta formatos solicitados (PDF, DWG, DWF)
   - Salva arquivos processados em `processados/{id}/exportados/`

---

## 📁 Estrutura de Arquivos VBA

### Module1.bas (Módulo Principal)
**Funções de Exportação:**
- `ExportarParaPDF()` - Envia arquivo ORIGINAL para servidor exportar PDF
- `ExportarParaDWG()` - Envia arquivo ORIGINAL para servidor exportar DWG
- `ExportarIDWtoDWF()` - Envia arquivo ORIGINAL para servidor exportar DWF
- `ExportarParaDXF()` - Exporta DXF localmente em `C:\GD_GEM\` (não envia ao servidor)
- `WriteSheetMetalDXF()` - Exporta DXF de chapa planificada localmente
- `ExportPartsListToCSV()` - Exporta CSV localmente em `C:\GD_GEM\` (não envia ao servidor)

**Configuração:**
```vba
Const SERVER_URL As String = "http://192.168.1.47:3001/api/desenhos/upload"
```

### ModuleUpload.bas (Módulo de Upload HTTP)
**Função Principal:**
- `EnviarArquivoParaServidor(sFilePath, sFileName, sCaminhoDestino, sFormatos())`
  - Lê arquivo ORIGINAL do disco
  - Monta requisição multipart/form-data
  - Envia via HTTP POST para servidor
  - Mostra logs no Debug.Print
  - Exibe mensagens de erro/sucesso

**Campos Enviados:**
- `nomeArquivo`: Nome do arquivo original
- `computador`: Nome do PC (Environ("COMPUTERNAME"))
- `caminhoDestino`: Caminho onde arquivos processados devem ser salvos
- `formatos`: Array JSON com formatos solicitados (ex: `["pdf", "dwg"]`)
- `arquivo`: Arquivo binário ORIGINAL (.ipt, .iam, .idw)

**Configuração:**
```vba
Const SERVER_URL As String = "http://192.168.1.47:3001/api/desenhos/upload"
```

### Module8.bas (Módulo BOM)
**Funções:**
- `BOMQuery()` - Consulta Bill of Materials
- `QueryBOMRowProperties()` - Processa linhas do BOM

**Observação:** Este módulo não interage com o servidor, apenas consulta dados locais do Inventor.

---

## 🔄 Fluxo Completo de Funcionamento

### 1. Exportação para Servidor (PDF, DWG, DWF)

```
┌─────────────────────────────────────────────────────────────┐
│ PC DO USUÁRIO (Cliente)                                      │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ 1. Usuário abre arquivo no Inventor
                    │    (ex: desenho.ipt)
                    │
                    │ 2. Usuário clica "Exportar PDF"
                    │
                    │ 3. Module1.ExportarParaPDF() é chamado
                    │
                    │ 4. Validações:
                    │    - Arquivo está salvo?
                    │    - É arquivo do Inventor (.ipt, .iam, .idw)?
                    │
                    │ 5. Chama ModuleUpload.EnviarArquivoParaServidor()
                    │    - Parâmetros:
                    │      * sFilePath: Caminho completo do arquivo ORIGINAL
                    │      * sFileName: Nome do arquivo
                    │      * sCaminhoDestino: "C:\GD_GEM\"
                    │      * sFormatos: ["pdf"]
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ ModuleUpload.bas                                             │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ 6. Lê arquivo ORIGINAL do disco (binário)
                    │
                    │ 7. Monta requisição multipart/form-data:
                    │    - Campos de texto (nomeArquivo, computador, etc)
                    │    - Arquivo binário ORIGINAL
                    │
                    │ 8. Envia HTTP POST para:
                    │    http://192.168.1.47:3001/api/desenhos/upload
                    │
                    │ 9. Logs no Debug.Print:
                    │    - "Iniciando upload para servidor"
                    │    - "Arquivo encontrado: ..."
                    │    - "Enviando arquivo para servidor..."
                    │    - "Status HTTP: 201"
                    │    - "Upload realizado com sucesso!"
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ SERVIDOR (192.168.1.47:3001)                                │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ 10. API recebe requisição POST
                    │     Endpoint: /api/desenhos/upload
                    │
                    │ 11. Multer salva arquivo em:
                    │     uploads/desenho_1234567890.ipt
                    │     (pasta temporária)
                    │
                    │ 12. Validações:
                    │     - Arquivo é .ipt, .iam ou .idw?
                    │     - Campos obrigatórios presentes?
                    │     - Formatos válidos?
                    │
                    │ 13. Gera ID único (UUID)
                    │
                    │ 14. Cria pasta permanente:
                    │     processados/{id}/
                    │
                    │ 15. Move arquivo de uploads/ para:
                    │     processados/{id}/desenho.ipt
                    │
                    │ 16. Salva no banco SQLite:
                    │     - id, nomeArquivo, computador, status='pendente'
                    │     - formatosSolicitados: ["pdf"]
                    │     - arquivoOriginal: caminho completo
                    │
                    │ 17. Adiciona à fila de processamento
                    │
                    │ 18. Responde HTTP 201 com:
                    │     {
                    │       "id": "uuid-gerado",
                    │       "status": "pendente",
                    │       "posicaoFila": 1,
                    │       "mensagem": "Arquivo recebido..."
                    │     }
                    │
                    │ 19. Worker processa arquivo:
                    │     - Abre arquivo no Inventor do servidor
                    │     - Exporta formatos solicitados
                    │     - Salva em: processados/{id}/exportados/
                    │       * desenho.pdf
                    │       * desenho.dwg
                    │       * desenho.dwf
                    │
                    │ 20. Atualiza status no banco:
                    │     - status: "processando" → "concluido"
                    │     - progresso: 0 → 100
                    │
                    │ 21. Arquivos processados ficam disponíveis
                    │     para download via API
```

### 2. Exportação Local (CSV, DXF)

```
┌─────────────────────────────────────────────────────────────┐
│ PC DO USUÁRIO (Cliente)                                      │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ 1. Usuário clica "Exportar CSV" ou "Exportar DXF"
                    │
                    │ 2. Module1.ExportPartsListToCSV() ou
                    │    Module1.ExportarParaDXF() é chamado
                    │
                    │ 3. Inventor exporta arquivo localmente:
                    │    - CSV: C:\GD_GEM\desenho.csv
                    │    - DXF: C:\GD_GEM\desenho.dxf
                    │
                    │ 4. NÃO é enviado ao servidor
                    │    (fica apenas no PC do usuário)
```

---

## 📂 Estrutura de Pastas no Servidor

### `uploads/` (Pasta Temporária)
- **Propósito**: Recebe arquivos enviados pelo multer
- **Fluxo**: Arquivo chega → Validação → Move para `processados/{id}/`
- **Duração**: Imediatamente após validação (arquivo é movido)
- **Conteúdo**: Vazio na maior parte do tempo (apenas buffer temporário)

### `processados/{id}/` (Pasta Permanente)
- **Propósito**: Armazena arquivos processados permanentemente
- **Estrutura**:
  ```
  processados/
  ├── {id-1}/
  │   ├── arquivo_original.ipt          # Arquivo ORIGINAL recebido
  │   └── exportados/                    # Pasta com arquivos processados
  │       ├── arquivo.pdf                # Exportado pelo servidor
  │       ├── arquivo.dwg                # Exportado pelo servidor
  │       └── arquivo.dwf                # Exportado pelo servidor
  ├── {id-2}/
  │   └── ...
  ```
- **Duração**: Permanente (arquivos ficam no servidor)
- **Conteúdo**: 
  - Arquivo ORIGINAL (.ipt, .iam, .idw)
  - Arquivos exportados em `exportados/`

---

## 🔧 Configuração

### IP do Servidor
O IP do servidor está configurado em **dois lugares**:

1. **Module1.bas** (linha 10):
   ```vba
   Const SERVER_URL As String = "http://192.168.1.47:3001/api/desenhos/upload"
   ```

2. **ModuleUpload.bas** (linha 7):
   ```vba
   Const SERVER_URL As String = "http://192.168.1.47:3001/api/desenhos/upload"
   ```

**Para alterar o IP do servidor**, edite essas duas constantes.

### Pasta Local (PC do Usuário)
- **CSV e DXF**: Exportados para `C:\GD_GEM\`
- **Verificar**: A pasta `C:\GD_GEM\` deve existir (criada automaticamente se não existir)

---

## 📋 Resumo por Tipo de Arquivo

| Formato | Onde é Processado | Onde Fica Salvo | Enviado ao Servidor? |
|---------|-------------------|-----------------|---------------------|
| **PDF** | Servidor | `processados/{id}/exportados/` | ✅ Sim (arquivo ORIGINAL) |
| **DWG** | Servidor | `processados/{id}/exportados/` | ✅ Sim (arquivo ORIGINAL) |
| **DWF** | Servidor | `processados/{id}/exportados/` | ✅ Sim (arquivo ORIGINAL) |
| **CSV** | PC do Usuário | `C:\GD_GEM\` | ❌ Não |
| **DXF** | PC do Usuário | `C:\GD_GEM\` | ❌ Não |

---

## 🐛 Debug e Logs

### Logs no VBA (Debug.Print)
Para ver os logs no Inventor:
1. Abra o Visual Basic Editor (`Alt+F11`)
2. Abra a janela **Immediate Window** (`Ctrl+G`)
3. Execute a exportação
4. Veja os logs em tempo real

**Exemplo de logs:**
```
========================================
Iniciando upload para servidor
========================================
Arquivo encontrado: C:\Users\...\desenho.ipt
Formatos validados: pdf
Objeto HTTP criado com sucesso
Arquivo lido: 1234567 bytes
Corpo da requisicao montado: 1234789 bytes
========================================
Enviando arquivo para servidor...
URL: http://192.168.1.47:3001/api/desenhos/upload
Arquivo: desenho.ipt
Tamanho: 1234567 bytes
Formatos: pdf
========================================
Enviando dados...
Status HTTP: 201
Status Text: Created
========================================
Upload realizado com sucesso!
Resposta: {"id":"...","status":"pendente",...}
========================================
```

### Logs no Servidor
Os logs aparecem no terminal onde o servidor está rodando:
- Recebimento de arquivo
- Validações
- Processamento
- Erros (se houver)

---

## ⚠️ Validações e Tratamento de Erros

### Validações no Cliente (VBA)
1. **Arquivo existe?**
   - Verifica se `sFilePath` existe no disco
   - Se não existir: mostra erro e interrompe

2. **Arquivo está salvo?**
   - Verifica se `oDoc.FullFileName` não está vazio
   - Se não estiver salvo: pede para salvar primeiro

3. **É arquivo do Inventor?**
   - Verifica se é `.ipt`, `.iam` ou `.idw`
   - Se não for: mostra erro

4. **Array de formatos válido?**
   - Verifica se `sFormatos()` tem elementos
   - Se inválido: mostra erro

5. **Conexão HTTP funcionando?**
   - Tenta criar objeto `MSXML2.XMLHTTP.6.0`
   - Se falhar: mostra erro

### Validações no Servidor (API)
1. **Arquivo recebido?**
   - Verifica se `req.file` existe
   - Se não: retorna HTTP 400

2. **Tipo de arquivo permitido?**
   - Verifica se extensão é `.ipt`, `.iam` ou `.idw`
   - Se não: retorna HTTP 400

3. **Campos obrigatórios?**
   - Verifica `nomeArquivo`, `computador`, `caminhoDestino`
   - Se faltar: retorna HTTP 400

4. **Formatos válidos?**
   - Verifica se pelo menos um formato válido foi especificado
   - Formatos válidos (Autodesk): `pdf`, `dwg`, `dxf`, `dwf`
   - Se inválido: retorna HTTP 400

### Tratamento de Erros
- **Cliente**: Mostra `MsgBox` com detalhes do erro
- **Servidor**: Retorna JSON com `erro` e `mensagem`
- **Logs**: Ambos registram erros para debug

---

## 🔍 Como Verificar se Está Funcionando

### 1. Verificar Upload
- Abra a janela **Immediate Window** no VBA (`Ctrl+G`)
- Execute uma exportação
- Veja os logs de upload
- Verifique se aparece "Upload realizado com sucesso!"

### 2. Verificar Servidor
- Veja os logs no terminal do servidor
- Deve aparecer: "Desenho recebido e adicionado à fila"
- Verifique se arquivo aparece em `processados/{id}/`

### 3. Verificar Banco de Dados
- Abra `database.db` (SQLite)
- Verifique se registro foi criado na tabela `desenhos`
- Status deve ser `pendente` inicialmente

### 4. Verificar Processamento
- Aguarde processamento pelo worker
- Status deve mudar para `processando` → `concluido`
- Arquivos devem aparecer em `processados/{id}/exportados/`

---

## 📝 Observações Importantes

1. **Arquivo ORIGINAL é Enviado**
   - O PC do usuário envia o arquivo ORIGINAL (.ipt, .iam, .idw)
   - O servidor processa e exporta os formatos solicitados
   - O PC do usuário **NÃO exporta** nada (servidor faz tudo)

2. **CSV e DXF Ficam Locais**
   - CSV e DXF são exportados localmente em `C:\GD_GEM\`
   - **NÃO são enviados ao servidor**
   - Usados apenas para consultas locais do usuário

3. **Pasta `uploads/` é Temporária**
   - Arquivos são movidos imediatamente para `processados/{id}/`
   - Não contém arquivos permanentes

4. **Pasta `processados/{id}/` é Permanente**
   - Cada desenho tem sua própria pasta com ID único
   - Arquivos processados ficam em `exportados/`
   - Arquivos ficam no servidor permanentemente

5. **Upload é Síncrono**
   - O VBA espera a resposta do servidor
   - Se falhar, mostra erro imediatamente
   - Se sucesso, mostra mensagem de confirmação

---

## 🚀 Próximos Passos

1. **Testar Upload**: Execute uma exportação e verifique os logs
2. **Verificar Servidor**: Confirme que arquivo chegou no servidor
3. **Aguardar Processamento**: Worker processa e exporta formatos
4. **Verificar Resultado**: Arquivos processados devem estar em `processados/{id}/exportados/`

---

## 📞 Troubleshooting

### Erro: "Arquivo não encontrado"
- Verifique se o arquivo está salvo no Inventor
- Verifique se o caminho está correto

### Erro: "Nao foi possivel criar objeto HTTP"
- Verifique se `MSXML2.XMLHTTP.6.0` está disponível no Windows
- Tente reiniciar o Inventor

### Erro: "Erro ao conectar com servidor"
- Verifique se o servidor está rodando em `192.168.1.47:3001`
- Verifique conexão de rede
- Verifique firewall

### Erro: "Status HTTP: 400"
- Verifique se campos obrigatórios foram enviados
- Verifique se formato de arquivo é válido (.ipt, .iam, .idw)
- Verifique se formatos solicitados são válidos

### Erro: "Status HTTP: 500"
- Erro interno do servidor
- Verifique logs do servidor para mais detalhes

---

**Documento criado em:** 2025-01-27  
**Versão:** 1.0  
**Autor:** Sistema de Exportação de Desenhos

