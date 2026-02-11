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
        
        ' Pasta de controle: lida de C:\jhonrob_controle_pasta.txt (escrito pelo VBS); fallback generico se nao existir
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
                ' Diagnostico: gravar que o macro recebeu o comando (pasta de controle)
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
    ' 1) Ler de %APPDATA%\JhonRob\ (mesmo usuario que o VBS)
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
    ' 2) Fallback: C:\ (ex.: Inventor aberto "como administrador")
    If LerPastaControle = "C:\jhonrob_inventor_controle" And fso.FileExists("C:\jhonrob_controle_pasta.txt") Then
        Set oFile = fso.OpenTextFile("C:\jhonrob_controle_pasta.txt", 1)
        If Not oFile Is Nothing And Not oFile.AtEndOfStream Then
            sLinha = Trim(oFile.ReadLine)
            If Len(sLinha) > 0 Then LerPastaControle = sLinha
        End If
        If Not oFile Is Nothing Then oFile.Close
        Set oFile = Nothing
    End If
    ' 3) Fallback fixo: T: (drive mapeado) ou UNC (mesmo recurso; VBA pode preferir T:)
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
        oDoc.Close False
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
    ' Codigo baseado no macro antigo Module1.bas ExportarParaDWG que funcionava
    On Error GoTo ErrorHandler
    ExportarDWGInterno = False
    
    Dim oApp As Application
    Dim oDrawingDoc As DrawingDocument
    Dim oTranslatorAddInDWG As TranslatorAddIn
    Dim oTranslationContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim addIn As ApplicationAddIn
    Dim addInFound As Boolean
    Dim fso As Object
    Dim logFile As String
    Dim logNum As Integer
    
    Set oApp = ThisApplication
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    ' Log para debug (pasta fixa para facilitar acesso em producao)
    logFile = "C:\gem-exportador\logs\gem-dwg-debug.log"
    ' Cria pasta se nao existir
    If Not fso.FolderExists("C:\gem-exportador\logs") Then
        fso.CreateFolder "C:\gem-exportador\logs"
    End If
    logNum = FreeFile
    Open logFile For Append As #logNum
    Print #logNum, "=== ExportarDWGInterno " & Now & " ==="
    Print #logNum, "Arquivo saida: " & sArquivoSaida
    Print #logNum, "DocumentType: " & oDoc.DocumentType
    Print #logNum, "kDrawingDocumentObject: " & kDrawingDocumentObject
    
    ' Verificar se o documento e um documento de desenho (ESSENCIAL!)
    If oDoc.DocumentType = kDrawingDocumentObject Then
        Print #logNum, "OK: Documento e DrawingDocument"
        ' Converter para DrawingDocument (ESSENCIAL para o AddIn funcionar!)
        Set oDrawingDoc = oDoc
        
        ' Procurar o AddIn do DWG Translator pelo ClassIdString (metodo do macro antigo)
        addInFound = False
        Print #logNum, "Procurando AddIn DWG..."
        For Each addIn In oApp.ApplicationAddIns
            If addIn.ClassIdString = "{C24E3AC2-122E-11D5-8E91-0010B541CD80}" Then
                Set oTranslatorAddInDWG = addIn
                addInFound = True
                Print #logNum, "OK: AddIn encontrado: " & addIn.DisplayName
                Exit For
            End If
        Next addIn

        If addInFound Then
            Print #logNum, "Criando contexto..."
            ' Criar o contexto de traducao
            Set oTranslationContext = oApp.TransientObjects.CreateTranslationContext
            oTranslationContext.Type = kFileBrowseIOMechanism

            ' Criar o objeto NameValueMap
            Set oOptions = oApp.TransientObjects.CreateNameValueMap

            ' Criar o objeto DataMedium
            Set oDataMedium = oApp.TransientObjects.CreateDataMedium
            oDataMedium.FileName = sArquivoSaida
            
            ' Preencher opcoes padrao para suprimir dialogo de exportacao
            If oTranslatorAddInDWG.HasSaveCopyAsOptions(oDrawingDoc, oTranslationContext, oOptions) Then
                Print #logNum, "OK: Opcoes padrao carregadas via HasSaveCopyAsOptions"
            Else
                Print #logNum, "AVISO: HasSaveCopyAsOptions retornou False (usando opcoes vazias)"
            End If
            
            ' Ativar modo silencioso para suprimir dialogos
            Print #logNum, "Ativando SilentOperation..."
            oApp.SilentOperation = True
            
            Print #logNum, "Chamando SaveCopyAs com opcoes preenchidas..."
            ' Exportar o DWG - passa oDrawingDoc (DrawingDocument), NAO oDoc!
            On Error Resume Next
            Call oTranslatorAddInDWG.SaveCopyAs(oDrawingDoc, oTranslationContext, oOptions, oDataMedium)
            
            ' Desativar modo silencioso
            oApp.SilentOperation = False
            If Err.Number <> 0 Then
                Print #logNum, "ERRO em SaveCopyAs: " & Err.Number & " - " & Err.Description
                Err.Clear
            Else
                Print #logNum, "SaveCopyAs executado sem erro"
            End If
            On Error GoTo ErrorHandler
            
            ' Verificar se o arquivo foi criado
            If fso.FileExists(sArquivoSaida) Then
                ExportarDWGInterno = True
                Print #logNum, "SUCESSO: Arquivo criado!"
            Else
                Print #logNum, "FALHA: Arquivo NAO foi criado"
            End If
            
            Set oDataMedium = Nothing
            Set oOptions = Nothing
            Set oTranslationContext = Nothing
            Set oTranslatorAddInDWG = Nothing
        Else
            Print #logNum, "ERRO: AddIn DWG nao encontrado!"
        End If
    Else
        Print #logNum, "ERRO: Documento NAO e DrawingDocument"
    End If
    
    Close #logNum
    Set fso = Nothing
    Exit Function
    
ErrorHandler:
    ThisApplication.SilentOperation = False
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
    
    ' Preencher opcoes padrao
    If oAddIn.HasSaveCopyAsOptions(oDoc, oContext, oOptions) Then
    End If
    
    ThisApplication.SilentOperation = True
    Call oAddIn.SaveCopyAs(oDoc, oContext, oOptions, oDataMedium)
    ThisApplication.SilentOperation = False
    
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
