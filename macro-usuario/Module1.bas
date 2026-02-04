Attribute VB_Name = "Module1"
Option Explicit

Global TipoArquivo As String
Global ExpTodos As Boolean

Const CONFIG_PATH As String = "C:\GD_GEM\config.ini"

Public Function ObterArquivosReferenciados(oDoc As Document) As String()
    ' TEMPORARIAMENTE DESABILITADO PARA ISOLAR O PROBLEMA
    Dim sArquivosRef() As String
    ReDim sArquivosRef(0 To -1)
    ObterArquivosReferenciados = sArquivosRef
    Exit Function
    
    On Error GoTo ErrorHandlerFunc
    
    ReDim sArquivosRef(0 To -1)
    Dim iCount As Integer
    Dim i As Integer
    Dim oRefFileDescs As ReferencedFileDescriptors
    Dim oRefFileDesc As ReferencedFileDescriptor
    Dim sCaminhoRef As String
    Dim sExt As String
    Dim oDrawingDoc As DrawingDocument
    Dim oReferencedDocs As Documents
    Dim oRefDoc As Document
    Dim sCaminhoRef2 As String
    Dim sExt2 As String
    
    iCount = 0
    
    If oDoc.DocumentType <> kDrawingDocumentObject Then
        ReDim sArquivosRef(0 To -1)
        ObterArquivosReferenciados = sArquivosRef
        Exit Function
    End If
    
    On Error Resume Next
    Set oRefFileDescs = oDoc.ReferencedFileDescriptors
    If Err.Number <> 0 Then
        Err.Clear
        GoTo SkipRefFileDescs
    End If
    If oRefFileDescs Is Nothing Then
        GoTo SkipRefFileDescs
    End If
    
    On Error Resume Next
    Dim iRefCount As Integer
    iRefCount = oRefFileDescs.Count
    If Err.Number <> 0 Or iRefCount <= 0 Then
        Err.Clear
        GoTo SkipRefFileDescs
    End If
    
    For i = 1 To iRefCount
        On Error Resume Next
        If i < 1 Or i > iRefCount Then
            Err.Clear
            GoTo NextRefFileDesc
        End If
        Set oRefFileDesc = oRefFileDescs.Item(i)
                    If Err.Number = 0 And Not oRefFileDesc Is Nothing Then
                    On Error Resume Next
                    sCaminhoRef = oRefFileDesc.FullFileName
                    If Err.Number <> 0 Then
                        Err.Clear
                        sCaminhoRef = ""
                    End If
                    Err.Clear
                    If Len(sCaminhoRef) >= 4 Then
                        sExt = LCase(Right(sCaminhoRef, 4))
                    Else
                        sExt = ""
                    End If
                    
                        If sCaminhoRef <> "" And Dir(sCaminhoRef) <> "" And (sExt = ".iam" Or sExt = ".ipt" Or sExt = ".idw") Then
                            On Error Resume Next
                            If iCount = 0 Then
                                ReDim sArquivosRef(0 To 0)
                            Else
                                ReDim Preserve sArquivosRef(0 To iCount)
                            End If
                            If Err.Number = 0 Then
                                On Error Resume Next
                                Dim iUBoundTest As Integer
                                iUBoundTest = UBound(sArquivosRef)
                                If Err.Number = 0 And iUBoundTest >= iCount Then
                                    sArquivosRef(iCount) = sCaminhoRef
                                    If Err.Number = 0 Then
                                        iCount = iCount + 1
                                    End If
                                End If
                                Err.Clear
                            End If
                            Err.Clear
                        End If
                    End If
                    Err.Clear
                End If
            Next
        End If
        Err.Clear
    End If
    Err.Clear
    
    If iCount = 0 Then
        Set oDrawingDoc = oDoc
        On Error Resume Next
        Set oReferencedDocs = oDrawingDoc.ReferencedDocuments
        If Err.Number <> 0 Then
            Err.Clear
            GoTo SkipReferencedDocs
        End If
        If oReferencedDocs Is Nothing Then
            GoTo SkipReferencedDocs
        End If
        
        On Error Resume Next
        Dim iRefDocsCount As Integer
        iRefDocsCount = oReferencedDocs.Count
        If Err.Number <> 0 Or iRefDocsCount <= 0 Then
            Err.Clear
            GoTo SkipReferencedDocs
        End If
        
        For i = 1 To iRefDocsCount
            On Error Resume Next
            If i < 1 Or i > iRefDocsCount Then
                Err.Clear
                GoTo NextReferencedDoc
            End If
            Set oRefDoc = oReferencedDocs.Item(i)
                        If Err.Number = 0 And Not oRefDoc Is Nothing Then
                        On Error Resume Next
                        sCaminhoRef2 = oRefDoc.FullFileName
                        If Err.Number <> 0 Then
                            Err.Clear
                            sCaminhoRef2 = ""
                        End If
                        Err.Clear
                        If Len(sCaminhoRef2) >= 4 Then
                            sExt2 = LCase(Right(sCaminhoRef2, 4))
                        Else
                            sExt2 = ""
                        End If
                        
                        If sCaminhoRef2 <> "" And Dir(sCaminhoRef2) <> "" And (sExt2 = ".iam" Or sExt2 = ".ipt" Or sExt2 = ".idw") Then
                                On Error Resume Next
                                If iCount = 0 Then
                                    ReDim sArquivosRef(0 To 0)
                                Else
                                    ReDim Preserve sArquivosRef(0 To iCount)
                                End If
                                If Err.Number = 0 Then
                                    On Error Resume Next
                                    Dim iUBoundTest2 As Integer
                                    iUBoundTest2 = UBound(sArquivosRef)
                                    If Err.Number = 0 And iUBoundTest2 >= iCount Then
                                        sArquivosRef(iCount) = sCaminhoRef2
                                        If Err.Number = 0 Then
                                            iCount = iCount + 1
                                        End If
                                    End If
                                    Err.Clear
                                End If
                                Err.Clear
                            End If
                        End If
                        Err.Clear
                    End If
                Next
            End If
            Err.Clear
        End If
        Err.Clear
    End If
    
    If iCount = 0 Then
        ReDim sArquivosRef(0 To -1)
    End If
    
    ObterArquivosReferenciados = sArquivosRef
End Function

Private Function IsUserForm1Loaded() As Boolean
    On Error Resume Next
    Dim test As String
    test = UserForm1.Caption
    IsUserForm1Loaded = (Err.Number = 0)
    On Error GoTo 0
End Function

Private Sub UpdateUserForm1Label(labelName As String, caption As String)
    On Error Resume Next
    If Not IsUserForm1Loaded() Then
        Err.Clear
        Exit Sub
    End If
    
    Dim oControl As Object
    On Error Resume Next
    Set oControl = UserForm1.Controls(labelName)
    If Err.Number <> 0 Or oControl Is Nothing Then
        Err.Clear
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    oControl.Caption = caption
    Err.Clear
    Set oControl = Nothing
End Sub

Sub DetectarTipoDeArquivoAberto()
    On Error GoTo erro
    Dim oDoc As Document
    Set oDoc = ThisApplication.ActiveDocument
    
    Select Case oDoc.DocumentType
        Case kPartDocumentObject
            TipoArquivo = "ipt"
        Case kAssemblyDocumentObject
            TipoArquivo = "iam"
        Case kDrawingDocumentObject
            TipoArquivo = "idw"
        Case Else
            TipoArquivo = ""
    End Select
    
    Exit Sub
erro:
    TipoArquivo = ""
End Sub

Sub Exportar_Arquivos()
    Call UserForm1.Show
End Sub

Sub ExportarParaDWG()
    On Error GoTo ErrorHandler
    
    Dim oDoc As Document
    Dim sArquivoOriginal As String
    Dim sFormatosStr As String
    Dim sDisplayNameDWG As String
    
    On Error Resume Next
    Call UpdateUserForm1Label("Label4", "Enviando para servidor...")
    Err.Clear
    
    On Error Resume Next
    Set oDoc = ThisApplication.ActiveDocument
    If Err.Number <> 0 Or oDoc Is Nothing Then
        Err.Clear
        MsgBox "Erro: Nenhum documento aberto", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sArquivoOriginal = oDoc.FullFileName
    If Err.Number <> 0 Or sArquivoOriginal = "" Then
        Err.Clear
        MsgBox "Por favor, salve o arquivo antes de enviar para o servidor.", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sDisplayNameDWG = oDoc.DisplayName
    If Err.Number <> 0 Or sDisplayNameDWG = "" Then
        Err.Clear
        sDisplayNameDWG = Mid(sArquivoOriginal, InStrRev(sArquivoOriginal, "\") + 1)
    End If
    Err.Clear
    
    sFormatosStr = "dwg"
    
    On Error GoTo ErrorHandler
    
    Call EnviarArquivoParaServidor(sArquivoOriginal, sDisplayNameDWG, "C:\GD_GEM\", sFormatosStr)
    
    On Error Resume Next
    If ExpTodos = True Then
        Call UpdateUserForm1Label("Label4", "Enviado...OK")
        Call UpdateUserForm1Label("Label6", "Enviado")
        Call UpdateUserForm1Label("Label7", "Arquivo enviado para servidor processar")
    Else
        Call UpdateUserForm1Label("Label4", "Enviado...OK")
        MsgBox "Arquivo enviado para servidor. O servidor processara e exportara DWG.", vbInformation
    End If
    Err.Clear
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar DWG: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
    On Error Resume Next
    Call UpdateUserForm1Label("Label4", "Erro")
    Err.Clear
End Sub

Sub ExportarParaDXF()
    On Error GoTo ErrorHandler
    
    Dim oApp As Inventor.Application
    Dim oDoc As Document
    Dim oDrawingDoc As DrawingDocument
    Dim oPartDoc As PartDocument
    Dim oAssemblyDoc As AssemblyDocument
    Dim oTranslatorAddIn As TranslatorAddIn
    Dim oTranslationContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim sOutputPath As String
    Dim sFileName As String
    
    Set oApp = ThisApplication
    Set oDoc = ThisApplication.ActiveDocument
    
    If oDoc Is Nothing Then
        MsgBox "Erro: Nenhum documento aberto", vbExclamation
        Exit Sub
    End If
    
    If oDoc.FullFileName = "" Then
        MsgBox "Por favor, salve o arquivo antes de exportar.", vbExclamation
        Exit Sub
    End If
    
    sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1)
    sOutputPath = "C:\GD_GEM\" & sFileName & ".dxf"
    
    Set oTranslatorAddIn = oApp.ApplicationAddIns.ItemById("{C24E3AC2-122E-11D5-8E3B-0010B541CD80}")
    
    If oTranslatorAddIn Is Nothing Then
        On Error GoTo ErrorHandler
        MsgBox "Erro: AddIn de traducao DWG nao encontrado", vbExclamation
        Exit Sub
    End If
    On Error GoTo ErrorHandler
    
    Set oTranslationContext = oApp.TransientObjects.CreateTranslationContext
    If oTranslationContext Is Nothing Then
        MsgBox "Erro: Nao foi possivel criar contexto de traducao", vbExclamation
        Exit Sub
    End If
    
    oTranslationContext.Type = kFileBrowseIOMechanism
    Set oOptions = oApp.TransientObjects.CreateNameValueMap
    Set oDataMedium = oApp.TransientObjects.CreateDataMedium
    
    oDataMedium.FileName = sOutputPath
    
    If oDoc.DocumentType = kDrawingDocumentObject Then
        Set oDrawingDoc = oDoc
        oTranslatorAddIn.SaveCopyAs(oDrawingDoc, oTranslationContext, oOptions, oDataMedium)
    ElseIf oDoc.DocumentType = kPartDocumentObject Then
        Set oPartDoc = oDoc
        oTranslatorAddIn.SaveCopyAs(oPartDoc, oTranslationContext, oOptions, oDataMedium)
    ElseIf oDoc.DocumentType = kAssemblyDocumentObject Then
        Set oAssemblyDoc = oDoc
        oTranslatorAddIn.SaveCopyAs(oAssemblyDoc, oTranslationContext, oOptions, oDataMedium)
    End If
    
    Call UpdateUserForm1Label("Label3", "Enviado...OK")
    MsgBox "Arquivo DXF exportado com sucesso para: " & sOutputPath, vbInformation
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar DXF: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
    Call UpdateUserForm1Label("Label3", "Erro")
End Sub

Sub ExportarParaPDF()
    On Error GoTo ErrorHandler
    
    Dim oDoc As Document
    Dim sArquivoOriginal As String
    Dim sFormatosStr As String
    Dim sDisplayName As String
    
    On Error Resume Next
    Call UpdateUserForm1Label("Label2", "Enviando para servidor...")
    Err.Clear
    
    On Error Resume Next
    Set oDoc = ThisApplication.ActiveDocument
    If Err.Number <> 0 Or oDoc Is Nothing Then
        Err.Clear
        MsgBox "Erro: Nenhum documento aberto", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sArquivoOriginal = oDoc.FullFileName
    If Err.Number <> 0 Or sArquivoOriginal = "" Then
        Err.Clear
        MsgBox "Por favor, salve o arquivo antes de enviar para o servidor.", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sDisplayName = oDoc.DisplayName
    If Err.Number <> 0 Or sDisplayName = "" Then
        Err.Clear
        sDisplayName = Mid(sArquivoOriginal, InStrRev(sArquivoOriginal, "\") + 1)
    End If
    Err.Clear
    
    sFormatosStr = "pdf"
    
    On Error GoTo ErrorHandler
    
    Call EnviarArquivoParaServidor(sArquivoOriginal, sDisplayName, "C:\GD_GEM\", sFormatosStr)
    
    On Error Resume Next
    Call UpdateUserForm1Label("Label2", "Enviado...OK")
    Err.Clear
    
    If ExpTodos = False Then
        MsgBox "Arquivo enviado para servidor. O servidor processara e exportara PDF.", vbInformation
    End If
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar PDF: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
    On Error Resume Next
    Call UpdateUserForm1Label("Label2", "Erro")
    Err.Clear
End Sub

Public Sub WriteSheetMetalDXF()
    On Error GoTo ErrorHandler
    
    If TipoArquivo = "ipt" Then
        Dim sFolderPath As String
        Dim sFileName As String
        Dim sFilePath As String
        Dim sOutputPath As String
        Dim oDoc As PartDocument
        Set oDoc = ThisApplication.ActiveDocument
        
        If oDoc Is Nothing Then
            MsgBox "Erro: Nenhum documento aberto", vbExclamation
            Exit Sub
        End If
        
        sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1)
        sFolderPath = "C:\GD_GEM\"
        sFilePath = oDoc.FullFileName
        sOutputPath = sFolderPath & sFileName & "_Chapa_DXF.dxf"
        
        Dim oFlatPattern As FlatPattern
        Set oFlatPattern = oDoc.ComponentDefinition.SheetMetal.FlatPattern
        
        If oFlatPattern Is Nothing Then
            MsgBox "Erro: Nao foi possivel obter o padrao plano da chapa", vbExclamation
            Exit Sub
        End If
        
        oFlatPattern.ExportFlatPattern(sOutputPath)
        
        Call UpdateUserForm1Label("Label3", "Enviado...OK")
        MsgBox "DXF de chapa planificada exportado com sucesso para: " & sOutputPath, vbInformation
    End If
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar DXF de chapa: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
    Call UpdateUserForm1Label("Label3", "Erro")
End Sub

Sub ExportPartsListToCSV()
    On Error GoTo ErrorHandler
    
    Dim sFolderPath As String
    Dim sFileName As String
    Dim sFilePath As String
    Dim sOutputPath As String
    
    Call UpdateUserForm1Label("Label5", "Gerando...")
    
    Dim oDrawDoc As DrawingDocument
    Set oDrawDoc = ThisApplication.ActiveDocument
    
    If oDrawDoc Is Nothing Or oDrawDoc.DocumentType <> kDrawingDocumentObject Then
        MsgBox "Erro: Abra um desenho (.idw) para exportar a lista de pecas", vbExclamation
        Exit Sub
    End If
    
    On Error Resume Next
    sFileName = Left(oDrawDoc.DisplayName, InStrRev(oDrawDoc.DisplayName, ".") - 1)
    If Err.Number <> 0 Or sFileName = "" Then
        Err.Clear
        sFileName = "Desenho"
    End If
    Err.Clear
    
    sFolderPath = "C:\GD_GEM\"
    sFilePath = oDrawDoc.FullFileName
    sOutputPath = sFolderPath & sFileName & ".csv"
    
    On Error Resume Next
    Dim oActiveSheet As Sheet
    Set oActiveSheet = oDrawDoc.ActiveSheet
    If Err.Number <> 0 Or oActiveSheet Is Nothing Then
        Err.Clear
        MsgBox "Erro: Nao foi possivel acessar a folha ativa do desenho", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    Dim oPartsLists As PartsLists
    Set oPartsLists = oActiveSheet.PartsLists
    If Err.Number <> 0 Or oPartsLists Is Nothing Then
        Err.Clear
        MsgBox "Erro: Nao foi possivel acessar a lista de pecas. Verifique se ha uma lista de pecas no desenho.", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    Dim iPartsListCount As Integer
    iPartsListCount = oPartsLists.Count
    If Err.Number <> 0 Or iPartsListCount = 0 Then
        Err.Clear
        MsgBox "Erro: Nao ha listas de pecas no desenho", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    Dim oPartList As PartsList
    Set oPartList = oPartsLists.Item(1)
    If Err.Number <> 0 Or oPartList Is Nothing Then
        Err.Clear
        MsgBox "Erro: Nao foi possivel acessar a primeira lista de pecas", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    Dim iRowsCount As Integer
    iRowsCount = oPartList.PartsListRows.Count
    If Err.Number <> 0 Or iRowsCount = 0 Then
        Err.Clear
        MsgBox "Erro: A lista de pecas esta vazia", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    Dim filePath As String
    filePath = sOutputPath
    Dim fileNumber As Integer
    fileNumber = FreeFile
    Open filePath For Output As #fileNumber
    
    Dim oRow As PartsListRow
    Dim i As Integer
    For i = 1 To iRowsCount
        On Error Resume Next
        If i >= 1 And i <= iRowsCount Then
            Set oRow = oPartList.PartsListRows.Item(i)
            If Err.Number = 0 And Not oRow Is Nothing Then
                On Error Resume Next
                Dim sPartNumber As String
                Dim sQuantity As String
                Dim sDescription As String
                sPartNumber = oRow.PartNumber
                If Err.Number <> 0 Then sPartNumber = ""
                Err.Clear
                sQuantity = CStr(oRow.Quantity)
                If Err.Number <> 0 Then sQuantity = ""
                Err.Clear
                sDescription = oRow.Description
                If Err.Number <> 0 Then sDescription = ""
                Err.Clear
                Print #fileNumber, sPartNumber & "," & sQuantity & "," & sDescription
            End If
            Err.Clear
        End If
        Err.Clear
    Next
    
    Close #fileNumber
    
    Call UpdateUserForm1Label("Label5", "Enviado...OK")
    MsgBox "Lista de pecas exportada com sucesso para: " & sOutputPath, vbInformation
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar CSV: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
    Call UpdateUserForm1Label("Label5", "Erro")
End Sub

Sub ExportarIDWtoDWF()
    On Error GoTo ErrorHandler
    
    Dim oDoc As Document
    Dim sArquivoOriginal As String
    Dim sFormatosStr As String
    Dim sDisplayNameDWF As String
    
    On Error Resume Next
    Set oDoc = ThisApplication.ActiveDocument
    If Err.Number <> 0 Or oDoc Is Nothing Then
        Err.Clear
        MsgBox "Nenhum documento aberto.", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sArquivoOriginal = oDoc.FullFileName
    If Err.Number <> 0 Or sArquivoOriginal = "" Then
        Err.Clear
        MsgBox "Por favor, salve o arquivo antes de enviar para o servidor.", vbExclamation
        Exit Sub
    End If
    Err.Clear
    
    On Error Resume Next
    sDisplayNameDWF = oDoc.DisplayName
    If Err.Number <> 0 Or sDisplayNameDWF = "" Then
        Err.Clear
        sDisplayNameDWF = Mid(sArquivoOriginal, InStrRev(sArquivoOriginal, "\") + 1)
    End If
    Err.Clear
    
    sFormatosStr = "dwf"
    
    On Error GoTo ErrorHandler
    
    Call EnviarArquivoParaServidor(sArquivoOriginal, sDisplayNameDWF, "C:\GD_GEM\", sFormatosStr)
    
    If ExpTodos = False Then
        MsgBox "Arquivo enviado para servidor. O servidor processara e exportara DWF.", vbInformation
    End If
    
    Exit Sub
    
ErrorHandler:
    MsgBox "Erro ao exportar DWF: " & Err.Description & " (Erro " & Err.Number & ")", vbExclamation
End Sub
