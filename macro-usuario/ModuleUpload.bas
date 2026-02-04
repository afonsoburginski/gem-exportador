Attribute VB_Name = "ModuleUpload"
Option Explicit

Const SERVER_URL As String = "http://192.168.1.66:3000/api/desenhos/upload"

Public Sub EnviarArquivoParaServidor(sFilePath As String, sFileName As String, sCaminhoDestino As String, sFormatosStr As String, Optional sArquivosReferenciados As Variant)
    On Error GoTo ErrorHandler
    
    Dim sErroMsg As String
    Dim oHTTP As Object
    Dim oBodyStream As Object
    Dim oTextStream As Object
    Dim sBoundary As String
    Dim iFileNum As Integer
    Dim lFileLen As Long
    Dim bFileData() As Byte
    Dim sTextPart As String
    Dim bTextBytes() As Byte
    Dim bBodyData() As Byte
    Dim lBodySize As Long
    Dim iUBoundBody As Long
    Dim sFormatosWork As String
    Dim sFormatosJSON As String
    Dim iPos As Integer
    Dim iNextPos As Integer
    Dim sFormatoTemp As String
    Dim bPrimeiroFormato As Boolean
    
    sFormatosWork = Trim(sFormatosStr)
    
    If sFormatosWork = "" Then
        sErroMsg = "Erro critico: String de formatos vazia"
        MsgBox sErroMsg, vbCritical, "Erro Critico"
        Exit Sub
    End If
    
    sFormatosJSON = "["
    bPrimeiroFormato = True
    iPos = 1
    
    Do While iPos > 0
        iNextPos = InStr(iPos, sFormatosWork, ",")
        If iNextPos > 0 Then
            sFormatoTemp = Trim(Mid(sFormatosWork, iPos, iNextPos - iPos))
            iPos = iNextPos + 1
        Else
            sFormatoTemp = Trim(Mid(sFormatosWork, iPos))
            iPos = 0
        End If
        
        If sFormatoTemp <> "" Then
            If Not bPrimeiroFormato Then
                sFormatosJSON = sFormatosJSON & ","
            End If
            sFormatosJSON = sFormatosJSON & Chr(34) & sFormatoTemp & Chr(34)
            bPrimeiroFormato = False
        End If
    Loop
    
    sFormatosJSON = sFormatosJSON & "]"
    
    If sFormatosJSON = "[]" Then
        sErroMsg = "Erro critico: Nao foi possivel construir JSON de formatos"
        MsgBox sErroMsg, vbCritical, "Erro Critico"
        Exit Sub
    End If
    
    On Error GoTo ErrorHandler
    
    ' Apenas arquivo principal - sem referências
    If sFilePath = "" Or sFileName = "" Then
        MsgBox "Erro: Caminho ou nome do arquivo esta vazio", vbExclamation
        Exit Sub
    End If
    
    If Dir(sFilePath) = "" Then
        MsgBox "Erro: Arquivo nao encontrado:" & vbCrLf & sFilePath, vbExclamation
        Exit Sub
    End If
    
    On Error Resume Next
    Set oHTTP = CreateObject("MSXML2.XMLHTTP.6.0")
    If Err.Number <> 0 Then
        MsgBox "Erro: Nao foi possivel criar objeto HTTP" & vbCrLf & _
               "Erro " & Err.Number & ": " & Err.Description, vbCritical
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    sBoundary = "----WebKitFormBoundary" & Format(Now, "yyyymmddhhnnss")
    
    On Error Resume Next
    iFileNum = FreeFile
    Open sFilePath For Binary Access Read As #iFileNum
    If Err.Number <> 0 Then
        If iFileNum > 0 Then Close #iFileNum
        Set oHTTP = Nothing
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    lFileLen = LOF(iFileNum)
    
    If lFileLen <= 0 Then
        Close #iFileNum
        Set oHTTP = Nothing
        MsgBox "Erro: Arquivo vazio ou tamanho invalido", vbExclamation
        Exit Sub
    End If
    
    On Error Resume Next
    ReDim bFileData(0 To lFileLen - 1)
    If Err.Number <> 0 Then
        Close #iFileNum
        Set oHTTP = Nothing
        MsgBox "Erro ao ler arquivo: " & Err.Description, vbExclamation
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    Get #iFileNum, , bFileData
    Close #iFileNum
    
    On Error Resume Next
    Set oBodyStream = CreateObject("ADODB.Stream")
    If Err.Number <> 0 Then
        Set oHTTP = Nothing
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    oBodyStream.Type = 1
    oBodyStream.Open
    
    Set oTextStream = CreateObject("ADODB.Stream")
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "nomeArquivo" & Chr(34) & vbCrLf & vbCrLf & _
                sFileName & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "computador" & Chr(34) & vbCrLf & vbCrLf & _
                Environ("COMPUTERNAME") & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "caminhoDestino" & Chr(34) & vbCrLf & vbCrLf & _
                sCaminhoDestino & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "formatos" & Chr(34) & vbCrLf & vbCrLf & _
                sFormatosJSON & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "caminhoOriginal" & Chr(34) & vbCrLf & vbCrLf & _
                sFilePath & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    sTextPart = "--" & sBoundary & vbCrLf & _
                "Content-Disposition: form-data; name=" & Chr(34) & "arquivo" & Chr(34) & "; filename=" & Chr(34) & sFileName & Chr(34) & vbCrLf & _
                "Content-Type: application/octet-stream" & vbCrLf & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    
    oBodyStream.Write bFileData
    
    ' Referências desabilitadas - sempre enviar apenas o arquivo principal
    ' O servidor vai processar e exportar
    
    sTextPart = vbCrLf & "--" & sBoundary & "--" & vbCrLf
    oTextStream.Type = 2
    oTextStream.Charset = "UTF-8"
    oTextStream.Open
    oTextStream.WriteText sTextPart
    oTextStream.Position = 0
    oTextStream.Type = 1
    oTextStream.Position = 3
    bTextBytes = oTextStream.Read
    oBodyStream.Write bTextBytes
    oTextStream.Close
    Set oTextStream = Nothing
    
    oBodyStream.Position = 0
    bBodyData = oBodyStream.Read
    oBodyStream.Close
    Set oBodyStream = Nothing
    
    On Error Resume Next
    iUBoundBody = UBound(bBodyData)
    If Err.Number <> 0 Then
        Err.Clear
        MsgBox "Erro: Corpo da requisicao invalido", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    lBodySize = iUBoundBody + 1
    If lBodySize = 0 Then
        MsgBox "Erro: Corpo da requisicao vazio", vbExclamation
        Set oHTTP = Nothing
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    On Error Resume Next
    oHTTP.Open "POST", SERVER_URL, False
    If Err.Number <> 0 Then
        MsgBox "Erro ao conectar com servidor:" & vbCrLf & _
               "Erro " & Err.Number & ": " & Err.Description & vbCrLf & _
               "URL: " & SERVER_URL, vbExclamation, "Erro de Conexao"
        Set oHTTP = Nothing
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    oHTTP.setRequestHeader "Content-Type", "multipart/form-data; boundary=" & sBoundary
    oHTTP.setRequestHeader "Content-Length", CStr(lBodySize)
    
    Dim vBodyData As Variant
    vBodyData = bBodyData
    oHTTP.send vBodyData
    
    If oHTTP.Status = 200 Or oHTTP.Status = 201 Then
    Else
        Dim sResposta As String
        On Error Resume Next
        sResposta = Left(oHTTP.responseText, 500)
        If Err.Number <> 0 Then
            sResposta = "Resposta nao disponivel"
            Err.Clear
        End If
        On Error GoTo ErrorHandler
        
        sErroMsg = "Erro no upload:" & vbCrLf & _
                   "Status: " & oHTTP.Status & " " & oHTTP.statusText & vbCrLf & _
                   "Resposta: " & sResposta
        MsgBox sErroMsg, vbExclamation, "Erro no Upload"
    End If
    
    Set oHTTP = Nothing
    Exit Sub
    
ErrorHandler:
    sErroMsg = "Erro ao enviar arquivo:" & vbCrLf & _
               "Erro " & Err.Number & ": " & Err.Description & vbCrLf & _
               "Linha: " & Erl
    MsgBox sErroMsg & vbCrLf & vbCrLf & _
           "Verifique:" & vbCrLf & _
           "1. Servidor esta rodando em " & SERVER_URL & vbCrLf & _
           "2. Conexao de rede esta funcionando" & vbCrLf & _
           "3. Firewall nao esta bloqueando", vbCritical, "Erro no Upload"
    
    On Error Resume Next
    If Not oHTTP Is Nothing Then Set oHTTP = Nothing
    If Not oBodyStream Is Nothing Then
        oBodyStream.Close
        Set oBodyStream = Nothing
    End If
    If Not oTextStream Is Nothing Then
        oTextStream.Close
        Set oTextStream = Nothing
    End If
End Sub
