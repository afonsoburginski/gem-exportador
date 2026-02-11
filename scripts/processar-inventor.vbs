' Script VBS para processar arquivos no Inventor via macro interno
' ESTRATEGIA: Escreve arquivo de comando e aguarda resultado do macro VBA
' O macro MacroServidor.IniciarServico deve estar rodando no Inventor do servidor
' Uso: cscript processar-inventor.vbs "C:\arquivo.idw" "C:\saida\" "pdf"

Option Explicit

Dim sArquivoEntrada, sPastaSaida, sFormatosStr, sPastaControle
If WScript.Arguments.Count < 3 Then
    WScript.Echo "ERRO: Faltam parametros"
    WScript.Quit 1
End If

sArquivoEntrada = WScript.Arguments(0)
sPastaSaida = WScript.Arguments(1)
sFormatosStr = WScript.Arguments(2)

Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")
If WScript.Arguments.Count >= 4 And Trim(WScript.Arguments(3)) <> "" Then
    sPastaControle = Replace(Trim(WScript.Arguments(3)), "/", "\")
Else
    Dim sScriptDir
    sScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
    sScriptDir = fso.GetParentFolderName(sScriptDir)
    sScriptDir = fso.GetParentFolderName(sScriptDir)
    sPastaControle = sScriptDir & "\processados"
End If

If sArquivoEntrada = "" Or sPastaSaida = "" Or sFormatosStr = "" Then
    WScript.Echo "ERRO: Parametros vazios"
    WScript.Quit 1
End If

Dim sNomeBase
sNomeBase = fso.GetBaseName(sArquivoEntrada)

If Not fso.FolderExists(sPastaSaida) Then
    fso.CreateFolder sPastaSaida
End If

Dim aFormatos, sFormato, sArquivoSaida, bSucesso, i
bSucesso = False
aFormatos = Split(sFormatosStr, ",")

For i = 0 To UBound(aFormatos)
    sFormato = LCase(Trim(aFormatos(i)))
    ' Remove barra final se existir para evitar duplicação
    If Right(sPastaSaida, 1) = "\" Then
        sArquivoSaida = sPastaSaida & sNomeBase & "." & sFormato
    Else
        sArquivoSaida = sPastaSaida & "\" & sNomeBase & "." & sFormato
    End If
    WScript.Echo "Exportando " & sFormato & ": " & sArquivoSaida
    
    If ExportarViaComando(sArquivoEntrada, sArquivoSaida, sFormato, sPastaControle) Then
        bSucesso = True
        WScript.Echo UCase(sFormato) & " OK!"
    End If
Next

Set fso = Nothing

If bSucesso Then
    WScript.Echo "SUCESSO"
    WScript.Quit 0
Else
    WScript.Echo "ERRO: Exportacao falhou"
    WScript.Quit 1
End If

Function ExportarViaComando(sEntrada, sSaida, sFormato, sBaseControle)
    On Error Resume Next
    ExportarViaComando = False
    
    Dim sComando, sSucesso, sErro, oControleFile
    sComando = sBaseControle & "\comando.txt"
    sSucesso = sBaseControle & "\sucesso.txt"
    sErro = sBaseControle & "\erro.txt"
    
    If Not fso.FolderExists(sBaseControle) Then fso.CreateFolder sBaseControle

    On Error Resume Next
    Dim oShell, sAppData, sControlePath
    Set oShell = CreateObject("WScript.Shell")
    sAppData = oShell.ExpandEnvironmentStrings("%APPDATA%")
    If Right(sAppData, 1) <> "\" Then sAppData = sAppData & "\"
    sControlePath = sAppData & "JhonRob\jhonrob_controle_pasta.txt"
    If Not fso.FolderExists(sAppData & "JhonRob") Then fso.CreateFolder sAppData & "JhonRob"
    Set oControleFile = fso.CreateTextFile(sControlePath, True)
    If Not oControleFile Is Nothing Then
        oControleFile.WriteLine sBaseControle
        oControleFile.Close
    End If
    Set oControleFile = Nothing
    Set oControleFile = fso.CreateTextFile("C:\jhonrob_controle_pasta.txt", True)
    If Not oControleFile Is Nothing Then
        oControleFile.WriteLine sBaseControle
        oControleFile.Close
    End If
    Set oControleFile = Nothing
    Set oShell = Nothing
    On Error GoTo 0
    
    WScript.Echo "Aguardando macro ficar livre..."
    Dim iPreWait
    For iPreWait = 1 To 30
        If Not fso.FileExists(sComando) And Not fso.FileExists(sSucesso) And Not fso.FileExists(sErro) Then
            Exit For
        End If
        WScript.Echo "  Limpando residuos anteriores..."
        If fso.FileExists(sComando) Then fso.DeleteFile sComando, True
        If fso.FileExists(sSucesso) Then fso.DeleteFile sSucesso, True
        If fso.FileExists(sErro) Then fso.DeleteFile sErro, True
        Err.Clear
        WScript.Sleep 2000
    Next
    
    If fso.FileExists(sSaida) Then 
        fso.DeleteFile sSaida, True
        WScript.Echo "Arquivo anterior removido"
    End If
    Err.Clear
    
    Dim sPasta
    sPasta = fso.GetParentFolderName(sSaida)
    If Not fso.FolderExists(sPasta) Then
        fso.CreateFolder sPasta
    End If
    
    WScript.Echo "Escrevendo comando: " & sFormato & " -> " & sSaida
    Dim oFile
    Set oFile = fso.CreateTextFile(sComando, True)
    oFile.WriteLine sEntrada & "|" & sSaida & "|" & sFormato
    oFile.Close
    Set oFile = Nothing
    
    WScript.Echo "Aguardando macro VBA processar..."
    WScript.Echo "(Certifique-se que o macro IniciarServico esta rodando no Inventor)"
    
    Dim iTimeout, iWait
    iTimeout = 1200  ' 20 minutos - DWGs pesados de assembly podem demorar MUITO
    
    For iWait = 1 To iTimeout
        WScript.Sleep 1000
        
        If fso.FileExists(sSucesso) Then
            WScript.Echo "Macro reportou SUCESSO! (" & iWait & "s)"
            
            Dim sSucessoContent
            sSucessoContent = ""
            On Error Resume Next
            Dim oSucFile
            Set oSucFile = fso.OpenTextFile(sSucesso, 1)
            If Not oSucFile Is Nothing Then
                sSucessoContent = Trim(oSucFile.ReadAll)
                oSucFile.Close
            End If
            Set oSucFile = Nothing
            On Error GoTo 0
            
            If fso.FileExists(sErro) Then fso.DeleteFile sErro, True
            If fso.FileExists(sSucesso) Then fso.DeleteFile sSucesso, True
            If fso.FileExists(sComando) Then fso.DeleteFile sComando, True
            Err.Clear
            
            WScript.Sleep 2000
            
            If fso.FileExists(sSaida) Then
                Dim oFileCheck
                Set oFileCheck = fso.GetFile(sSaida)
                If oFileCheck.Size > 0 Then
                    WScript.Echo "Arquivo criado: " & oFileCheck.Size & " bytes"
                    ExportarViaComando = True
                Else
                    WScript.Echo "Arquivo criado mas vazio!"
                End If
                Set oFileCheck = Nothing
            Else
                WScript.Echo "AVISO: sucesso.txt criado mas arquivo nao existe no destino!"
                WScript.Echo "  Destino esperado: " & sSaida
                WScript.Echo "  Conteudo sucesso.txt: " & sSucessoContent
            End If
            Exit Function
        End If
        
        If fso.FileExists(sErro) Then
            Dim oErroFile, sMsgErro
            Set oErroFile = fso.OpenTextFile(sErro, 1)
            sMsgErro = oErroFile.ReadAll
            oErroFile.Close
            Set oErroFile = Nothing
            WScript.Echo "Macro reportou ERRO (" & iWait & "s): " & sMsgErro
            
            If fso.FileExists(sErro) Then fso.DeleteFile sErro, True
            If fso.FileExists(sSucesso) Then fso.DeleteFile sSucesso, True
            If fso.FileExists(sComando) Then fso.DeleteFile sComando, True
            Err.Clear
            Exit Function
        End If
        
        If iWait Mod 10 = 0 Then
            WScript.Echo "Aguardando... " & iWait & "s/" & iTimeout & "s"
        End If
    Next
    
    WScript.Echo "TIMEOUT: Macro nao respondeu em " & iTimeout & " segundos"
    WScript.Echo "Verifique se o macro IniciarServico esta rodando no Inventor!"
    
    If fso.FileExists(sComando) Then fso.DeleteFile sComando, True
    Err.Clear
End Function
