Attribute VB_Name = "MacroServidor"
Option Explicit

Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
Private bServicoAtivo As Boolean

Public Sub Auto_Open()
    Call IniciarServicoSilencioso
End Sub

Public Sub IniciarServicoSilencioso()
    Dim fso As Object
    Dim sBaseControle As String
    Dim sComando As String
    Dim sLinha As String
    Dim aParams() As String
    Dim sArquivoEntrada As String
    Dim sArquivoSaida As String
    Dim sFormato As String
    Dim oFile As Object
    
    Set fso = CreateObject("Scripting.FileSystemObject")
    bServicoAtivo = True
    
    Do While bServicoAtivo
        DoEvents
        
        If ThisApplication Is Nothing Then Exit Do
        If Not ThisApplication.Ready Then Exit Do
        
        sBaseControle = LerPastaControle(fso)
        sComando = sBaseControle & "\comando.txt"
        
        If fso.FileExists(sComando) Then
            On Error Resume Next
            
            Set oFile = fso.OpenTextFile(sComando, 1)
            If Not oFile.AtEndOfStream Then
                sLinha = oFile.ReadLine
                aParams = Split(sLinha, "|")
                If UBound(aParams) >= 2 Then
                    sArquivoEntrada = Trim(aParams(0))
                    sArquivoSaida = Trim(aParams(1))
                    sFormato = LCase(Trim(aParams(2)))
                End If
            End If
            oFile.Close
            Set oFile = Nothing
            
            fso.DeleteFile sComando, True
            
            If Len(sArquivoEntrada) > 0 And Len(sArquivoSaida) > 0 Then
                Call EscreverLinhaArquivo(fso, sBaseControle & "\macro_recebeu.txt", "OK " & Format(Now(), "yyyy-mm-dd hh:nn:ss") & " " & sArquivoEntrada)
                Call ProcessarComando(fso, sArquivoEntrada, sArquivoSaida, sFormato, sBaseControle)
            End If
            
            On Error GoTo 0
        End If
        
        Sleep 500
    Loop
    
    Set fso = Nothing
End Sub

Public Sub IniciarServico()
    MsgBox "Servico iniciado!" & vbCrLf & "Aguardando comandos...", vbInformation, "Servidor"
    Call IniciarServicoSilencioso
    MsgBox "Servico encerrado.", vbInformation, "Servidor"
End Sub

Public Sub PararServico()
    bServicoAtivo = False
End Sub

Private Function LerPastaControle(fso As Object) As String
    On Error Resume Next
    Dim oFile As Object
    Dim sControlePath As String
    Dim sLinha As String
    LerPastaControle = "C:\jhonrob_inventor_controle"
    sControlePath = Environ("APPDATA") & "\JhonRob\jhonrob_controle_pasta.txt"
    If fso.FileExists(sControlePath) Then
        Set oFile = fso.OpenTextFile(sControlePath, 1)
        If Not oFile Is Nothing And Not oFile.AtEndOfStream Then
            sLinha = Trim(oFile.ReadLine)
            If Len(sLinha) > 0 Then LerPastaControle = sLinha
        End If
        If Not oFile Is Nothing Then oFile.Close
        Set oFile = Nothing
    End If
    If LerPastaControle = "C:\jhonrob_inventor_controle" And fso.FileExists("C:\jhonrob_controle_pasta.txt") Then
        Set oFile = fso.OpenTextFile("C:\jhonrob_controle_pasta.txt", 1)
        If Not oFile Is Nothing And Not oFile.AtEndOfStream Then
            sLinha = Trim(oFile.ReadLine)
            If Len(sLinha) > 0 Then LerPastaControle = sLinha
        End If
        If Not oFile Is Nothing Then oFile.Close
        Set oFile = Nothing
    End If
    If LerPastaControle = "C:\jhonrob_inventor_controle" Then
        If fso.FolderExists("T:\desenhos gerenciador 3D\processados") Then
            LerPastaControle = "T:\desenhos gerenciador 3D\processados"
        Else
            LerPastaControle = "\\srvmtgem1\Arquivos$\desenhos gerenciador 3D\processados"
        End If
    End If
    On Error GoTo 0
End Function

Private Sub ProcessarComando(fso As Object, sArquivoEntrada As String, sArquivoSaida As String, sFormato As String, Optional sBaseControle As String = "")
    On Error GoTo ErrorHandler
    
    Dim oDoc As Document
    Dim bAbrimos As Boolean
    bAbrimos = False
    
    ThisApplication.SilentOperation = True
    
    Set oDoc = ThisApplication.ActiveDocument
    
    If oDoc Is Nothing Then
        Set oDoc = ThisApplication.Documents.Open(sArquivoEntrada, True)
        bAbrimos = True
    ElseIf LCase(oDoc.FullFileName) <> LCase(sArquivoEntrada) Then
        Set oDoc = ThisApplication.Documents.Open(sArquivoEntrada, True)
        bAbrimos = True
    End If
    
    DoEvents
    
    Dim bSucesso As Boolean
    bSucesso = False
    
    Select Case sFormato
        Case "pdf"
            bSucesso = ExportarPDFInterno(oDoc, sArquivoSaida)
        Case "dwg", "dxf"
            bSucesso = ExportarDWGInterno(oDoc, sArquivoSaida)
        Case "dwf"
            bSucesso = ExportarDWFInterno(oDoc, sArquivoSaida)
    End Select
    
    If bAbrimos Then
        On Error Resume Next
        oDoc.Close True
        Err.Clear
        On Error GoTo ErrorHandler
    End If
    
    ThisApplication.SilentOperation = False
    
    If Len(sBaseControle) = 0 Then sBaseControle = LerPastaControle(fso)
    If bSucesso Then
        Call EscreverSucesso(fso, sArquivoSaida, sBaseControle)
    Else
        Call EscreverErro(fso, "Exportacao " & sFormato & " falhou - verifique se o formato e suportado", sBaseControle)
    End If
    
    Exit Sub
    
ErrorHandler:
    ThisApplication.SilentOperation = False
    If Len(sBaseControle) = 0 Then sBaseControle = LerPastaControle(fso)
    Call EscreverErro(fso, "Erro " & Err.Number & ": " & Err.Description & " [" & sFormato & "]", sBaseControle)
End Sub

Private Function ExportarPDFInterno(oDoc As Document, sArquivoSaida As String) As Boolean
    On Error GoTo ErrorHandler
    ExportarPDFInterno = False
    
    Dim oPDFAddIn As TranslatorAddIn
    Dim oContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    
    Set oPDFAddIn = ThisApplication.ApplicationAddIns.ItemById("{0AC6FD96-2F4D-42CE-8BE0-8AEA580399E4}")
    
    If oPDFAddIn Is Nothing Then Exit Function
    
    If Not oPDFAddIn.Activated Then
        oPDFAddIn.Activate
    End If
    
    Set oContext = ThisApplication.TransientObjects.CreateTranslationContext
    oContext.Type = kFileBrowseIOMechanism
    
    Set oOptions = ThisApplication.TransientObjects.CreateNameValueMap
    Set oDataMedium = ThisApplication.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sArquivoSaida
    
    If oPDFAddIn.HasSaveCopyAsOptions(oDoc, oContext, oOptions) Then
    End If
    
    Call oPDFAddIn.SaveCopyAs(oDoc, oContext, oOptions, oDataMedium)
    
    ExportarPDFInterno = True
    
    Set oDataMedium = Nothing
    Set oOptions = Nothing
    Set oContext = Nothing
    Set oPDFAddIn = Nothing
    Exit Function
    
ErrorHandler:
    ExportarPDFInterno = False
End Function

Private Function ExportarDWGInterno(oDoc As Document, sArquivoSaida As String) As Boolean
    On Error GoTo ErrorHandler
    ExportarDWGInterno = False
    
    Dim oApp As Application
    Dim oDrawingDoc As DrawingDocument
    Dim oTranslator As TranslatorAddIn
    Dim oContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim fso As Object
    Dim logFile As String
    Dim logNum As Integer
    Dim iWait As Integer
    Dim sTempFile As String
    Dim lSize As Long
    
    Set oApp = ThisApplication
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    logFile = "C:\gem-exportador\logs\gem-dwg-debug.log"
    If Not fso.FolderExists("C:\gem-exportador") Then fso.CreateFolder "C:\gem-exportador"
    If Not fso.FolderExists("C:\gem-exportador\logs") Then fso.CreateFolder "C:\gem-exportador\logs"
    logNum = FreeFile
    Open logFile For Output As #logNum
    Print #logNum, "=== ExportarDWGInterno " & Now & " ==="
    Print #logNum, "Saida: " & sArquivoSaida
    Print #logNum, "DocType: " & oDoc.DocumentType
    
    If oDoc.DocumentType <> kDrawingDocumentObject Then
        Print #logNum, "ERRO: Nao e DrawingDocument"
        GoTo Cleanup
    End If
    
    Set oDrawingDoc = oDoc
    sTempFile = Environ("TEMP") & "\" & fso.GetBaseName(sArquivoSaida) & ".dwg"
    
    On Error Resume Next
    If fso.FileExists(sTempFile) Then fso.DeleteFile sTempFile, True
    If fso.FileExists(sArquivoSaida) Then fso.DeleteFile sArquivoSaida, True
    Err.Clear
    On Error GoTo ErrorHandler
    
    Print #logNum, "--- Padrao Module1 DXF: ItemById + Options vazio + DrawingDoc ---"
    
    On Error Resume Next
    Set oTranslator = oApp.ApplicationAddIns.ItemById("{C24E3AC2-122E-11D5-8E91-0010B541CD80}")
    If Err.Number <> 0 Or oTranslator Is Nothing Then
        Err.Clear
        Print #logNum, "AddIn 8E91 nao encontrado, tentando 8E3B..."
        Set oTranslator = oApp.ApplicationAddIns.ItemById("{C24E3AC2-122E-11D5-8E3B-0010B541CD80}")
    End If
    If Err.Number <> 0 Or oTranslator Is Nothing Then
        Err.Clear
        Print #logNum, "ERRO: Nenhum AddIn DWG encontrado"
        GoTo Cleanup
    End If
    Err.Clear
    On Error GoTo ErrorHandler
    
    Print #logNum, "AddIn: " & oTranslator.DisplayName & " [" & oTranslator.ClassIdString & "]"
    
    If Not oTranslator.Activated Then oTranslator.Activate
    
    Set oContext = oApp.TransientObjects.CreateTranslationContext
    oContext.Type = kFileBrowseIOMechanism
    Set oOptions = oApp.TransientObjects.CreateNameValueMap
    Set oDataMedium = oApp.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sTempFile
    
    Print #logNum, "SaveCopyAs com DrawingDoc + Options vazio -> temp local..."
    On Error Resume Next
    Call oTranslator.SaveCopyAs(oDrawingDoc, oContext, oOptions, oDataMedium)
    If Err.Number <> 0 Then
        Print #logNum, "Erro: " & Err.Number & " - " & Err.Description
        Err.Clear
    Else
        Print #logNum, "SaveCopyAs OK (sem erro)"
    End If
    On Error GoTo ErrorHandler
    
    DoEvents
    Sleep 3000
    DoEvents
    
    If Not fso.FileExists(sTempFile) Then
        Print #logNum, "Aguardando arquivo temp..."
        For iWait = 1 To 30
            DoEvents
            Sleep 1000
            If fso.FileExists(sTempFile) Then
                Print #logNum, "Arquivo apareceu em " & (iWait + 3) & "s"
                Exit For
            End If
            If iWait Mod 10 = 0 Then Print #logNum, "  " & (iWait + 3) & "s..."
        Next iWait
    End If
    
    If fso.FileExists(sTempFile) Then
        lSize = fso.GetFile(sTempFile).Size
        Print #logNum, "Temp criado: " & lSize & " bytes"
        If lSize > 100 Then
            On Error Resume Next
            fso.CopyFile sTempFile, sArquivoSaida, True
            If Err.Number = 0 Then
                Print #logNum, "SUCESSO: copiado para " & sArquivoSaida
                ExportarDWGInterno = True
            Else
                Print #logNum, "Erro copiar para rede: " & Err.Description
                Err.Clear
            End If
            fso.DeleteFile sTempFile, True
            Err.Clear
            On Error GoTo ErrorHandler
            If ExportarDWGInterno Then GoTo Cleanup
        End If
    Else
        Print #logNum, "Temp NAO criado com Options vazio"
    End If
    
    Print #logNum, "--- Fallback: SaveCopyAs direto na rede ---"
    Set oOptions = oApp.TransientObjects.CreateNameValueMap
    Set oDataMedium = oApp.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sArquivoSaida
    
    On Error Resume Next
    Call oTranslator.SaveCopyAs(oDrawingDoc, oContext, oOptions, oDataMedium)
    If Err.Number <> 0 Then
        Print #logNum, "Fallback erro: " & Err.Number & " - " & Err.Description
        Err.Clear
    Else
        Print #logNum, "Fallback SaveCopyAs OK"
    End If
    On Error GoTo ErrorHandler
    
    DoEvents
    Sleep 3000
    DoEvents
    
    If Not fso.FileExists(sArquivoSaida) Then
        For iWait = 1 To 30
            DoEvents
            Sleep 1000
            If fso.FileExists(sArquivoSaida) Then Exit For
            If iWait Mod 10 = 0 Then Print #logNum, "  Rede " & (iWait + 3) & "s..."
        Next iWait
    End If
    
    If fso.FileExists(sArquivoSaida) Then
        Print #logNum, "SUCESSO fallback: " & sArquivoSaida
        ExportarDWGInterno = True
    Else
        Print #logNum, "FALHA TOTAL"
    End If
    
    Set oDataMedium = Nothing
    Set oOptions = Nothing
    Set oContext = Nothing
    Set oTranslator = Nothing

Cleanup:
    Close #logNum
    Set fso = Nothing
    Exit Function
    
ErrorHandler:
    Print #logNum, "ERRO FATAL: " & Err.Number & " - " & Err.Description
    Close #logNum
    Set fso = Nothing
    ExportarDWGInterno = False
End Function

Private Function ExportarDWFInterno(oDoc As Document, sArquivoSaida As String) As Boolean
    On Error GoTo ErrorHandler
    ExportarDWFInterno = False
    
    Dim oAddIn As TranslatorAddIn
    Dim oContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    
    Set oAddIn = ThisApplication.ApplicationAddIns.ItemById("{0AC6FD95-2F4D-42CE-8BE0-8AEA580399E4}")
    
    If oAddIn Is Nothing Then Exit Function
    
    If Not oAddIn.Activated Then
        oAddIn.Activate
    End If
    
    Set oContext = ThisApplication.TransientObjects.CreateTranslationContext
    oContext.Type = kFileBrowseIOMechanism
    
    Set oOptions = ThisApplication.TransientObjects.CreateNameValueMap
    Set oDataMedium = ThisApplication.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sArquivoSaida
    
    If oAddIn.HasSaveCopyAsOptions(oDoc, oContext, oOptions) Then
    End If
    
    Call oAddIn.SaveCopyAs(oDoc, oContext, oOptions, oDataMedium)
    
    ExportarDWFInterno = True
    
    Set oDataMedium = Nothing
    Set oOptions = Nothing
    Set oContext = Nothing
    Set oAddIn = Nothing
    Exit Function
    
ErrorHandler:
    ExportarDWFInterno = False
End Function

Private Sub EscreverLinhaArquivo(fso As Object, sCaminhoCompleto As String, sLinha As String)
    On Error Resume Next
    Dim oFile As Object
    Set oFile = fso.CreateTextFile(sCaminhoCompleto, True)
    If Not oFile Is Nothing Then
        oFile.WriteLine sLinha
        oFile.Close
    End If
    Set oFile = Nothing
    On Error GoTo 0
End Sub

Private Sub EscreverSucesso(fso As Object, sMsg As String, Optional sBase As String = "")
    Dim oFile As Object
    If Len(sBase) = 0 Then sBase = LerPastaControle(fso)
    Set oFile = fso.CreateTextFile(sBase & "\sucesso.txt", True)
    oFile.WriteLine sMsg
    oFile.Close
    Set oFile = Nothing
End Sub

Private Sub EscreverErro(fso As Object, sMsg As String, Optional sBase As String = "")
    Dim oFile As Object
    If Len(sBase) = 0 Then sBase = LerPastaControle(fso)
    Set oFile = fso.CreateTextFile(sBase & "\erro.txt", True)
    oFile.WriteLine sMsg
    oFile.Close
    Set oFile = Nothing
End Sub
