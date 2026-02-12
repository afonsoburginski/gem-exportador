# Scripts para Processamento no Servidor

## 📄 processar-inventor.vbs

Script VBS que processa arquivos diretamente via COM automation do Inventor, **sem depender de macro VBA**.

### Uso

```bash
cscript processar-inventor.vbs "C:\arquivo.iam" "C:\saida\" "pdf,dwg" [pasta_controle]
```

### Parâmetros

1. **Arquivo de entrada**: Caminho completo do arquivo Inventor (.ipt, .iam, .idw)
2. **Pasta de saída**: Pasta onde salvar os arquivos exportados
3. **Formatos**: Lista de formatos separados por vírgula (ex: `pdf,dwg,dwf`)
4. **Pasta de controle** (opcional): Pasta para `comando.txt`/`sucesso.txt`/`erro.txt`. Se omitido, usa `...\processados` derivada da localização do script (funciona em qualquer drive/pasta de instalação).

### Como Funciona

1. Cria objeto `Inventor.Application` via COM
2. Configura Inventor em modo silencioso (sem diálogos)
3. Abre o arquivo solicitado
4. Processa cada formato solicitado diretamente via COM
5. Fecha o documento sem salvar
6. Retorna código de saída 0 se sucesso, 1 se erro

### Requisitos

- ✅ Autodesk Inventor instalado no servidor
- ❌ **NÃO precisa mais** do macro VBA importado no Inventor

### Formatos utilizados nesta ferramenta

Ordem de processamento: **PDF → DWF → DWG** (somente esses três).

- `pdf` - PDF (funciona para Drawing, Part e Assembly)
  - Drawing: exporta diretamente
  - Part/Assembly: cria Drawing temporário e exporta
- `dwf` - Design Web Format (apenas Drawing)
- `dwg` - AutoCAD DWG (apenas Drawing) — sempre por último (mais pesado)

### Características

- ✅ Modo totalmente silencioso (sem diálogos)
- ✅ Processamento direto via COM (não depende de macro VBA)
- ✅ Não interfere com outras janelas do Windows
- ✅ Processamento isolado e estável
- ✅ Logs detalhados via `WScript.Echo`

### Notas Importantes

- O script deve estar na pasta `servidor/scripts/` quando o servidor roda
- Quando usar `serve.exe`, o script deve estar na mesma pasta ou em `scripts/` relativo ao executável
- **NÃO é necessário** importar macro VBA no Inventor do servidor
- Este é o **único script necessário** para processamento
- O script processa arquivos diretamente via COM automation do Inventor

### Vantagens da Abordagem Direta

- ✅ **Mais simples**: Não precisa instalar macro no Inventor
- ✅ **Mais confiável**: Não depende de `RunMacro` (que pode não estar disponível via COM)
- ✅ **Mais fácil de debugar**: Logs diretos no `stdout` do cscript
- ✅ **Menos pontos de falha**: Menos componentes para configurar

---

**Última atualização:** 2025-12-02  
**Versão:** 3.0 (processamento direto via COM, sem macro VBA)
