Attribute VB_Name = "Module1"
Option Explicit

Global TipoArquivo As String
Global ExpTodos As Boolean


 
 
 Sub DetectarTipoDeArquivoAberto()
 
 On Error GoTo erro
    ' Variável para armazenar o documento ativo
    Dim oDoc As Document
    Set oDoc = ThisApplication.ActiveDocument
    
    ' Verificar o tipo de documento
    Select Case oDoc.DocumentType
        Case kPartDocumentObject
            'MsgBox "O arquivo aberto é um Part (.ipt)"
            TipoArquivo = "ipt"
        Case kAssemblyDocumentObject
            'MsgBox "O arquivo aberto é um Assembly (.iam)"
                TipoArquivo = "iam"
        Case kDrawingDocumentObject
            'MsgBox "O arquivo aberto é um Drawing (.idw)"
                TipoArquivo = "idw"
        Case Else
            MsgBox "Tipo de documento desconhecido"
    End Select
erro:

End Sub


Sub Exportar_Arquivos()
Load UserForm1
UserForm1.CommandButton1.Visible = False
UserForm1.CommandButton2.Visible = False
UserForm1.CommandButton3.Visible = False
UserForm1.CommandButton6.Top = UserForm1.CommandButton2.Top
UserForm1.CommandButton4.Top = UserForm1.CommandButton3.Top
UserForm1.Show
End Sub

Sub ExportarParaDWG()
    ' Desativado - exportacao gerenciada pelo servidor
    Exit Sub
    
    Dim oApp As Application
    Dim oDoc As Document
    Dim oDrawingDoc As DrawingDocument
    Dim oTranslatorAddInDWG As TranslatorAddIn
    Dim oTranslationContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim sFolderPath As String
    Dim sFileName As String
    Dim sFilePath As String
    Dim sOutputPath As String
    
    
      UserForm1.Label4.Caption = "Gerando..."
    ' Configurar a aplicação do Inventor
    Set oApp = ThisApplication

    ' Obter o documento ativo
    Set oDoc = oApp.ActiveDocument
    
    ' Verificar se o documento ativo é um documento de desenho
    If oDoc.DocumentType = kDrawingDocumentObject Then
        Set oDrawingDoc = oDoc
        
        
        ' Definir o caminho da pasta do documento ativo
        sFolderPath = oDoc.FullFileName
        sFolderPath = Left(sFolderPath, InStrRev(sFolderPath, "\"))

        ' Definir o caminho de saída para os arquivos DWG
        sOutputPath = "C:\GD_GEM\"
        
        ' Criar a pasta de saída se ela não existir
        If Dir(sOutputPath, vbDirectory) = "" Then
            MkDir sOutputPath
        End If
        
        ' Definir o nome do arquivo DWG
        sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1) & ".dwg"
        sFilePath = sOutputPath & sFileName
        
        ' Procurar o AddIn do DWG Translator
        Dim addIn As ApplicationAddIn
        Dim addInFound As Boolean
        addInFound = False
        For Each addIn In oApp.ApplicationAddIns
        
            If addIn.ClassIdString = "{C24E3AC4-122E-11D5-8E91-0010B541CD80}" Then ' Tentativa com ID padrão
                Set oTranslatorAddInDWG = addIn
                addInFound = True
                Exit For
            End If
        Next addIn

        If addInFound Then
            ' Criar o contexto de tradução
            Set oTranslationContext = oApp.TransientObjects.CreateTranslationContext
            oTranslationContext.Type = kFileBrowseIOMechanism

            ' Criar o objeto NameValueMap
            Set oOptions = oApp.TransientObjects.CreateNameValueMap

            ' Configurar opções específicas para a exportação de DWG, se necessário
            ' Exemplo: oOptions.Value("Export_Acad_IniFile") = "C:\path\to\your\iniFile.ini"

            ' Criar o objeto DataMedium
            Set oDataMedium = oApp.TransientObjects.CreateDataMedium
            oDataMedium.FileName = sFilePath

            ' Exportar o DWG
            Call oTranslatorAddInDWG.SaveCopyAs(oDrawingDoc, oTranslationContext, oOptions, oDataMedium)
            
            ' Notificar o usuário
            If ExpTodos = True Then
            UserForm1.Label4.Caption = "Gerando...OK"
            UserForm1.Label6.Caption = "Finalizado"
            UserForm1.Label7.Caption = "Arquivos DXF e CSV exportados com sucesso para C:\GD_GEM"
            ExpTodos = False
            Else
            UserForm1.Label4.Caption = "Gerando...OK"
            UserForm1.Label6.Caption = "Finalizado"
            MsgBox "DWG exportado com sucesso para " & sFilePath
            End If
        Else
            MsgBox "DWG Translator AddIn nao encontrado."
        End If
    Else
        MsgBox "O documento ativo nao e um documento de desenho."
    End If
End Sub
Sub ExportarParaDXF()
    Dim oApp As Inventor.Application
    Dim oDoc As Document
    Dim oDrawingDoc As DrawingDocument
    Dim oPartDoc As PartDocument
    Dim oAssemblyDoc As AssemblyDocument
    Dim oTranslatorAddIn As TranslatorAddIn
    Dim oTranslationContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim sFolderPath As String
    Dim sFileName As String
    Dim sFilePath As String
    Dim sOutputPath As String
    UserForm1.Label3.Caption = "Gerando..."
    ' Set the Inventor application
    Set oApp = ThisApplication

    ' Get the active document
    Set oDoc = oApp.ActiveDocument

    ' Define the folder path of the active document
    sFolderPath = oDoc.FullFileName
    sFolderPath = Left(sFolderPath, InStrRev(sFolderPath, "\"))

    ' Define the output path for DXFs
    sOutputPath = "C:\GD_GEM\"
    
    ' Create the output folder if it doesn't exist
    'If Dir(sOutputPath, vbDirectory) = "" Then
       'MkDir sOutputPath
    'End If

    ' Define the DXF file name
    sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1) & ".dxf"
    sFilePath = sOutputPath & sFileName

    ' Get the DXF Translator AddIn
    Set oTranslatorAddIn = oApp.ApplicationAddIns.ItemById("{C24E3AC4-122E-11D5-8E91-0010B541CD80}") ' Inventor DXF translator ID

    ' Create the translation context
    Set oTranslationContext = oApp.TransientObjects.CreateTranslationContext
    oTranslationContext.Type = kFileBrowseIOMechanism

    ' Create NameValueMap object
    Set oOptions = oApp.TransientObjects.CreateNameValueMap

    ' Create DataMedium object
    Set oDataMedium = oApp.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sFilePath

    ' Check the document type and export accordingly
    If oDoc.DocumentType = kDrawingDocumentObject Then
        ' If the active document is a drawing document
        Set oDrawingDoc = oDoc
        ' Export the DXF
        Call oTranslatorAddIn.SaveCopyAs(oDrawingDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
            If ExpTodos = True Then
            UserForm1.Label3.Caption = "Gerando...OK"
            Else
            UserForm1.Label3.Caption = "Gerando...OK"
            MsgBox "DXF do desenho exportado com sucesso para " & sFilePath
            End If
    ElseIf oDoc.DocumentType = kAssemblyDocumentObject Then
        ' If the active document is an assembly document
        Set oAssemblyDoc = oDoc
        ' Export the DXF
        Call oTranslatorAddIn.SaveCopyAs(oDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
        UserForm1.Label3.Caption = "Gerando...OK"
        MsgBox "DXF da montagem exportado com sucesso para " & sFilePath
        
    ElseIf oDoc.DocumentType = kPartDocumentObject Then
        ' If the active document is a part document
        Set oPartDoc = oDoc
        ' Export the DXF
        Call oTranslatorAddIn.SaveCopyAs(oDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
        
        If ExpTodos = True Then
        UserForm1.Label3.Caption = "Gerando...OK"
        MsgBox "DXF da peca exportado com sucesso para " & sFilePath
        Else
        UserForm1.Label3.Caption = "Gerando...OK"
        End If
        
    Else
        MsgBox "O documento ativo nao e um documento de desenho, montagem ou peca."
    End If
End Sub

Sub ExportarParaPDF()
    ' Desativado - exportacao gerenciada pelo servidor
    Exit Sub
    
    Dim oApp As Inventor.Application
    Dim oDoc As Document
    Dim oDrawingDoc As DrawingDocument
    Dim oPartDoc As PartDocument
    Dim oAssemblyDoc As AssemblyDocument
    Dim oTranslatorAddIn As TranslatorAddIn
    Dim oTranslationContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim sFolderPath As String
    Dim sFileName As String
    Dim sFilePath As String
    Dim sOutputPath As String
    UserForm1.Label2.Caption = "Gerando..."
    ' Set the Inventor application
    Set oApp = ThisApplication

    ' Get the active document
    Set oDoc = oApp.ActiveDocument

    ' Define the folder path of the active document
    sFolderPath = oDoc.FullFileName
    sFolderPath = Left(sFolderPath, InStrRev(sFolderPath, "\"))

    ' Define the output path for PDFs
   ' sOutputPath = sFolderPath & "PDFs\"
    sOutputPath = "C:\GD_GEM\"
    ' Create the output folder if it doesn't exist
    'If Dir(sOutputPath, vbDirectory) = "" Then
      '  MkDir sOutputPath
    'End If

    ' Define the PDF file name
    sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1) & ".pdf"
    sFilePath = sOutputPath & sFileName

    ' Get the PDF Translator AddIn
    Set oTranslatorAddIn = oApp.ApplicationAddIns.ItemById("{0AC6FD96-2F4D-42CE-8BE0-8AEA580399E4}")

    ' Create the translation context
    Set oTranslationContext = oApp.TransientObjects.CreateTranslationContext
    oTranslationContext.Type = kFileBrowseIOMechanism

    ' Create NameValueMap object
    Set oOptions = oApp.TransientObjects.CreateNameValueMap

    ' Create DataMedium object
    Set oDataMedium = oApp.TransientObjects.CreateDataMedium
    oDataMedium.FileName = sFilePath

    ' Check the document type and export accordingly
    If oDoc.DocumentType = kDrawingDocumentObject Then
        ' If the active document is a drawing document
        Set oDrawingDoc = oDoc
        ' Export the PDF
        Call oTranslatorAddIn.SaveCopyAs(oDrawingDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
        
        If ExpTodos = True Then
        UserForm1.Label2.Caption = "Gerando...OK"
        Else
        UserForm1.Label2.Caption = "Gerando...OK"
        MsgBox "PDF do desenho exportado com sucesso para " & sFilePath
        End If
        
    ElseIf oDoc.DocumentType = kAssemblyDocumentObject Then
        ' If the active document is an assembly document
        Set oAssemblyDoc = oDoc
        ' Zoom extend for assembly
        oApp.CommandManager.ControlDefinitions.Item("AppZoomAllCmd").Execute
        ' Export the PDF
        Call oTranslatorAddIn.SaveCopyAs(oDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
        If ExpTodos = True Then
        UserForm1.Label2.Caption = "Gerando...OK"
        MsgBox "PDF do desenho exportado com sucesso para " & sFilePath
        Else
        UserForm1.Label2.Caption = "Gerando...OK"
        End If
    ElseIf oDoc.DocumentType = kPartDocumentObject Then
        ' If the active document is a part document
        Set oPartDoc = oDoc
        ' Zoom extend for part
        oApp.CommandManager.ControlDefinitions.Item("AppZoomAllCmd").Execute
        ' Export the PDF
        Call oTranslatorAddIn.SaveCopyAs(oDoc, oTranslationContext, oOptions, oDataMedium)
        ' Notify the user
        
        If ExpTodos = True Then
        UserForm1.Label2.Caption = "Gerando...OK"
        MsgBox "PDF da peca exportado com sucesso para " & sFilePath
        Else
        UserForm1.Label2.Caption = "Gerando...OK"
        End If
        
    Else
        MsgBox "O documento ativo nao e um documento de desenho, montagem ou peca."
    End If
End Sub

Public Sub WriteSheetMetalDXF()
        If TipoArquivo = "ipt" Then
            Dim sFolderPath As String
            Dim sFileName As String
            Dim sFilePath As String
            Dim sOutputPath As String
            ' Get the active document.  This assumes it is a part document.
            Dim oDoc As PartDocument
            Set oDoc = ThisApplication.ActiveDocument
            UserForm1.Label3.Caption = "Gerando..."
            sFolderPath = oDoc.FullFileName
            sFolderPath = Left(sFolderPath, InStrRev(sFolderPath, "\"))
             sFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1) & ".dxf"
            
             sOutputPath = "C:\GD_GEM\"
             'sFilePath = sOutputPath & sFileName
             sFilePath = sOutputPath & sFileName
             
        
            ' Get the DataIO object.
            Dim oDataIO As DataIO
            Set oDataIO = oDoc.ComponentDefinition.DataIO
        
            ' Build the string that defines the format of the DXF file.
            'Codigo com Parametros
            'Funcionando 21/07/2024
            'sOut = "FLAT PATTERN DXF?AcadVersion=2004&OuterProfileLayer=Outer&TrimCenterlinesAtContour=True&BendUpLayerColor=0;0;255&BendDownLayerColor=255;0;0&InteriorProfilesLayer=IV_MARK_THROUGH&InteriorProfilesLayerColor=255;255;255&InvisibleLayers=IV_TANGENT;IV_TOOL_CENTER;IV_TOOL_CENTER_DOWN;IV_ARC_CENTERS;IV_FEATURE_PROFILES;IV_FEATURE_PROFILES_DOWN"
            'Fucionando 09/12/2024
            'sOut = "FLAT PATTERN DXF?AcadVersion=2004&OuterProfileLayer=Outer&TrimCenterlinesAtContour=True&BendUpLayerColor=0;0;255&BendDownLayerColor=255;0;0&FeatureProfilesLayerColor=0;0;255&InteriorProfilesLayer=IV_MARK_THROUGH&InteriorProfilesLayerColor=255;255;255&InvisibleLayers=IV_TANGENT;IV_TOOL_CENTER;IV_TOOL_CENTER_DOWN;IV_ARC_CENTERS"
            'Fucionando 30/04/2025
            'sOut = "FLAT PATTERN DXF?AcadVersion=2004&OuterProfileLayer=Outer&TrimCenterlinesAtContour=True&BendUpLayerColor=0;0;255&BendDownLayerColor=255;0;0&FeatureProfilesUpLayerColor=0;0;255&InteriorProfilesLayer=IV_MARK_THROUGH&InteriorProfilesLayerColor=255;255;255&InvisibleLayers=IV_TANGENT;IV_TOOL_CENTER;IV_TOOL_CENTER_DOWN;IV_ARC_CENTERS;IV_FEATURE_PROFILES_DOWN"
            'Alteração 20/05/2025
            'sOut = "FLAT PATTERN DXF?AcadVersion=2004&OuterProfileLayer=Outer&TrimCenterlinesAtContour=True&BendUpLayerColor=0;0;255&BendDownLayerColor=255;0;0&FeatureProfilesUpLayerColor=0;0;255&InteriorProfilesLayer=IV_MARK_THROUGH;IV_MARK_SURFACE_BACK&InteriorProfilesLayerColor=255;255;255&InvisibleLayers=IV_TANGENT;IV_TOOL_CENTER;IV_TOOL_CENTER_DOWN;IV_ARC_CENTERS;IV_FEATURE_PROFILES_DOWN;IV_UNCONSUMED_SKETCHES;IV_UNCONSUMED_SKETCH_CONSTRUCTION"
            
            
            Dim sOut As String
                        
            sOut = "FLAT PATTERN DXF?AcadVersion=2004&OuterProfileLayer=Outer&TrimCenterlinesAtContour=True&BendUpLayerColor=0;0;255&BendDownLayerColor=255;0;0&FeatureProfilesUpLayerColor=0;0;255&InteriorProfilesLayer=IV_MARK_THROUGH&InteriorProfilesLayerColor=255;255;255&InvisibleLayers=IV_TANGENT;IV_TOOL_CENTER;IV_TOOL_CENTER_DOWN;IV_ARC_CENTERS;IV_FEATURE_PROFILES_DOWN;IV_UNCONSUMED_SKETCHES;IV_UNCONSUMED_SKETCH_CONSTRUCTION&AltRepFrontLayer=IV_MARK_SURFACE&AltRepFrontLayerColor=0;0;255&AltRepFrontLayerLineType=37634&AltRepBackLayer=IV_MARK_SURFACE_BACK&AltRepBackLayerColor=255;0;0&AltRepBackLayerLineType=37634"
            
            ' Create the DXF file.
            oDataIO.WriteDataToFile sOut, sFilePath
            
            If ExpTodos = True Then
            UserForm1.Label3.Caption = "Gerando...OK"
            Else
             UserForm1.Label3.Caption = "Gerando...OK"
            MsgBox "DXF da peca exportado com sucesso com definicoes do Flat Pattern para " & sFilePath
            End If
            
        Else
        
        If ExpTodos = True Then
         UserForm1.Label3.Caption = "Gerando...OK"
        Else
         UserForm1.Label3.Caption = "Gerando...OK"
        MsgBox "Este arquivo e um " & "." & TipoArquivo & " a exportacao DXF e para peca planificada formato .ipt"
        End If
        
    End If
        
End Sub
Sub ExportPartsListToCSV()
    Dim sFolderPath As String
    Dim sFileName As String
    Dim sFilePath As String
    Dim sOutputPath As String
    UserForm1.Label5.Caption = "Gerando..."
    ' Definir uma referência ao documento de desenho ativo.
    Dim oDrawDoc As DrawingDocument
    Set oDrawDoc = ThisApplication.ActiveDocument
    
    ' Verificar se o documento ativo é um documento de desenho.
    If Not oDrawDoc.DocumentType = kDrawingDocumentObject Then
        MsgBox "Este codigo deve ser executado em um documento de desenho do Inventor.", vbExclamation
        Exit Sub
    End If
    
    ' Obter o caminho da pasta do documento de desenho ativo.
    sFolderPath = oDrawDoc.FullFileName
    sFolderPath = Left(sFolderPath, InStrRev(sFolderPath, "\"))
    
    ' Definir o nome do arquivo CSV com base no nome do documento de desenho.
    sFileName = Left(oDrawDoc.DisplayName, InStrRev(oDrawDoc.DisplayName, ".") - 1) & ".csv"
    sOutputPath = "C:\GD_GEM\"  ' Caminho onde o arquivo CSV será salvo
    sFilePath = sOutputPath & sFileName
    
    ' Verificar se há alguma lista de peças na folha ativa.
    If oDrawDoc.ActiveSheet.PartsLists.Count = 0 Then
        MsgBox "Nenhuma lista de pecas encontrada na folha ativa.", vbExclamation
        Exit Sub
    End If
    
    ' Definir uma referência à primeira lista de peças na folha ativa.
    Dim oPartList As PartsList
    Set oPartList = oDrawDoc.ActiveSheet.PartsLists.Item(1)
    
    ' Caminho do arquivo CSV a ser criado.
    Dim filePath As String
    filePath = sFilePath
    
    ' Criar e abrir um arquivo de texto para escrita.
    Dim fileNumber As Integer
    fileNumber = FreeFile
    Open filePath For Output As #fileNumber
    
    ' Escrever a linha de cabeçalho.
    Dim header As String
    Dim j As Long
    For j = 1 To oPartList.PartsListColumns.Count
        header = header & oPartList.PartsListColumns.Item(j).Title
        If j < oPartList.PartsListColumns.Count Then
            header = header & ";"
        End If
    Next j
    Print #fileNumber, header
    
    ' Iterar através do conteúdo da lista de peças.
    Dim i As Long
    For i = 1 To oPartList.PartsListRows.Count
        ' Obter a linha atual.
        Dim oRow As PartsListRow
        Set oRow = oPartList.PartsListRows.Item(i)
        
        ' Preparar os dados da linha.
        Dim rowData As String
        rowData = ""  ' Inicializar a variável rowData
        
        For j = 1 To oPartList.PartsListColumns.Count
            ' Obter a célula atual.
            Dim oCell As PartsListCell
            Set oCell = oRow.Item(j)
            
            ' Adicionar valor da célula aos dados da linha.
            rowData = rowData & oCell.Value
            If j < oPartList.PartsListColumns.Count Then
                rowData = rowData & ";"
            End If
        Next j
        
        ' Escrever os dados da linha no arquivo CSV.
        Print #fileNumber, rowData
    Next i
    
    ' Fechar o arquivo.
    Close #fileNumber
    If ExpTodos = True Then
    UserForm1.Label5.Caption = "Gerando...OK"
    Else
    UserForm1.Label5.Caption = "Gerando...OK"
    MsgBox "Lista de pecas exportada com sucesso para " & filePath, vbInformation
    End If
End Sub

Sub ExportarIDWtoDWF()
    ' Desativado - exportacao gerenciada pelo servidor
    Exit Sub
    
    ' Declaração das variáveis
    Dim oApp As Application
    Dim oDoc As DrawingDocument
    Dim oDWFAddIn As TranslatorAddIn
    Dim oContext As TranslationContext
    Dim oOptions As NameValueMap
    Dim oDataMedium As DataMedium
    Dim strFileName As String
    Dim strFilePath As String
    
    ' Obter a aplicação ativa
    Set oApp = ThisApplication
    
    ' Obter o documento IDW ativo
    On Error Resume Next
    Set oDoc = oApp.ActiveDocument
    On Error GoTo 0
    
    
    
    ' Verificar se o documento ativo é um desenho (IDW)
    If Not oDoc Is Nothing Then
        If oDoc.DocumentType = kDrawingDocumentObject Then
            ' Obter o nome do arquivo sem a extensão
            strFileName = Left(oDoc.DisplayName, InStrRev(oDoc.DisplayName, ".") - 1)
            
            ' Definir o caminho de salvamento para C:\temp\ com o mesmo nome do arquivo original
            strFilePath = "C:\GD_GEM\" & strFileName & ".dwf"
            
            ' Obter o add-in de exportação para DWF
            Set oDWFAddIn = oApp.ApplicationAddIns.ItemById("{0AC6FD96-2F4D-42CE-8BE0-8AEA580399E4}")
            
            ' Verificar se o add-in está carregado
            If Not oDWFAddIn Is Nothing Then
                ' Criar um contexto de tradução
                Set oContext = oApp.TransientObjects.CreateTranslationContext
                oContext.Type = kFileBrowseIOMechanism
                
                ' Criar um NameValueMap para as opções de exportação
                Set oOptions = oApp.TransientObjects.CreateNameValueMap
                
                ' Configurar opções para garantir fundo branco e modo completo
                oOptions.Value("PublishMode") = kCompleteDWFPublish ' Modo completo
                oOptions.Value("SheetBackground") = False  ' Desativa o fundo para ter fundo branco
                
                ' Criar um DataMedium para especificar o arquivo de saída
                Set oDataMedium = oApp.TransientObjects.CreateDataMedium
                oDataMedium.FileName = strFilePath
                
                ' Exportar o documento para DWF
                oDWFAddIn.SaveCopyAs oDoc, oContext, oOptions, oDataMedium
                If ExpTodos = True Then
               
                Else
                 MsgBox "Exportacao concluida com sucesso! Arquivo salvo em: " & strFilePath
                End If
                
            Else
                MsgBox "O add-in de exportacao DWF nao esta disponivel."
            End If
        Else
            MsgBox "O documento ativo nao e um arquivo de desenho (IDW)."
        End If
    Else
        MsgBox "Geracao de Arquivos somente do Arquivo .IDW"
    End If
End Sub

