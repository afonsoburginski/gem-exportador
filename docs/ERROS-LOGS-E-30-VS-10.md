# Erros nos logs e causa dos 30 enviados / 10 recebidos

## Resumo do problema
- Já existiam **2** desenhos do JUNIOR VENSON no banco.
- Ele enviou **30**; chegaram apenas **10** naquele envio.
- Total no banco: **12** (2 + 10).

## Erros identificados nos logs

### 1. Servidor (gem-exportador.log)
- **VBS retornou código 1** – Vários desenhos falham na exportação DWG/DWF/PDF (Inventor/macro não conclui a tempo ou arquivo em uso).
- **LazyStandaloneCoroutine was cancelled** – Coroutine cancelada (ex.: servidor reiniciado ou timeout).
- **A tentativa de conexão falhou** – Perda de conexão com o PostgreSQL (rede ou DB reiniciado).
- **Exceção não tratada** – Erros não capturados em algum fluxo.

### 2. Desktop (gem-exportador-desktop.log)
- **Cancelar rejeitado pelo servidor (400 Bad Request): "Desenho já cancelado"** – Usuário clica em cancelar mas o desenho já tinha sido cancelado antes; o servidor devolve 400. (Pode ser tratado no cliente para não mostrar erro ao usuário.)

Nenhum desses erros é “só 10 requests aceitos”: o servidor **não** rejeita nem limita a 10. Ou seja, o problema dos 30→10 **não** foi erro de lógica sua no servidor (não é “erro da sua parte” no sentido de bug no backend).

## Causa provável dos 30 → 10

Os 30 itens são enviados por **requisições HTTP POST** para `POST /api/desenhos/queue`.  
No log do **servidor** aparecem apenas os INSERTs que de fato chegaram (no período do JUNIOR VENSON foram 12 no total no dia, sendo 10 naquele envio + 2 já existentes).

Conclusão: **parte dos POSTs nunca chegou ao servidor**. Possíveis causas:

1. **Cliente que envia os 30** (script, planilha, outro app no PC do JUNIOR VENSON):
   - Limite de **conexões HTTP simultâneas** (ex.: 10) e o resto timeout ou falha.
   - Envio em paralelo sem retry: quando muitas requisições são abertas de uma vez, só parte completa.
2. **Rede** – perda de pacotes ou timeout entre o PC dele e o 192.168.1.116.
3. **Timeout no cliente** – se o cliente usa timeout curto e o servidor está carregado, parte dos POSTs pode falhar.

O app desktop (Kotlin) **não** aparece nos logs como tendo enviado esses itens (não há “Desenho enviado para fila” no gem-exportador-desktop.log), então os 30 vêm de **outro** programa/script.

## O que foi feito no código

1. **Log no servidor**  
   Ao receber cada `POST /api/desenhos/queue`, o servidor grava:
   - `[POST queue] recebido: <nome_arquivo> (<computador>)`  
   Assim você vê no **gem-exportador.log** exatamente quantos POSTs chegaram.

2. **Endpoint em lote**  
   - **POST /api/desenhos/queue/batch**  
   - Corpo: **array JSON** com até 100 itens no mesmo formato de `QueueBody` (nomeArquivo, computador, caminhoDestino, arquivoOriginal, formatos).  
   - Um único HTTP request pode enviar 30 (ou até 100) desenhos; o servidor insere todos.  
   - Assim não há limite de “10 conexões” por request: **30 enviados em 1 request = 30 recebidos**.

## O que fazer na prática

1. **Quem envia os 30**  
   - Se for um script ou outra aplicação no PC do JUNIOR VENSON, altere para usar **POST /api/desenhos/queue/batch** com um array de 30 itens em vez de 30 POSTs separados.  
   - Exemplo de corpo (batch com 2 itens):
     ```json
     [
       {
         "nomeArquivo": "850000238_01.idw",
         "computador": "JUNIOR VENSON",
         "caminhoDestino": "\\\\192.168.1.152\\Arquivos$\\DESENHOS GERENCIADOR\\850",
         "arquivoOriginal": "\\\\192.168.1.152\\Arquivos$\\DESENHOS GERENCIADOR 3D\\850\\850000238_01.idw",
         "formatos": ["pdf", "dwf", "dwg"]
       },
       ...
     ]
     ```

2. **Se continuar com 30 POSTs separados**  
   - Enviar **em sequência** (um após o outro), com pequeno intervalo (ex.: 100–200 ms) entre cada POST, para evitar estourar limite de conexões e timeouts.

3. **Conferir no log**  
   - Depois do próximo envio, ver no **gem-exportador.log** quantas linhas `[POST queue] recebido:` aparecem.  
   - Se forem 30, o servidor está recebendo tudo; se forem menos, o problema segue no cliente/rede.

## Resumo
- **Erros nos logs:** VBS/Inventor, coroutine cancelada, conexão com DB; nenhum indica “limite de 10” no servidor.
- **30→10:** os POSTs que “sumiram” não chegaram ao servidor; a causa é cliente (muitas conexões/timeout) ou rede.
- **Solução:** usar **POST /api/desenhos/queue/batch** para enviar os 30 (ou quantos forem) em uma única requisição.
