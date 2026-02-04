Attribute VB_Name = "Module8"
Option Explicit

Global FirstLevelOnly As Boolean
Global Lin As Integer

' ============================================================
' Funcao Auxiliar para UserForm2
' ============================================================
Private Function IsUserForm2Loaded() As Boolean
    On Error Resume Next
    Dim test As String
    test = UserForm2.Caption
    IsUserForm2Loaded = (Err.Number = 0)
    On Error GoTo 0
End Function

Private Sub SafeAddItemToListBox(item As String, quantity As String, partNumber As String, description As String, rowIndex As Integer)
    On Error Resume Next
    UserForm2.ListBox1.AddItem
    UserForm2.ListBox1.List(rowIndex, 0) = item
    UserForm2.ListBox1.List(rowIndex, 1) = quantity
    UserForm2.ListBox1.List(rowIndex, 2) = partNumber
    UserForm2.ListBox1.List(rowIndex, 3) = description
    On Error GoTo 0
End Sub

Public Sub BOMQuery()
If TipoArquivo <> "iam" Then MsgBox "Gera somente de arquivo .iam aberto": Exit Sub

    ' Set a reference to the assembly document.
    ' This assumes an assembly document is active.
    Dim oDoc As AssemblyDocument
    Set oDoc = ThisApplication.ActiveDocument

    'Dim FirstLevelOnly As Boolean
    If MsgBox("First level only?", vbYesNo) = vbYes Then
        FirstLevelOnly = True
    Else
        FirstLevelOnly = False
    End If
    
    ' Set a reference to the BOM
    Dim oBOM As bom
    Set oBOM = oDoc.ComponentDefinition.bom
    
    ' Set whether first level only or all levels.
    If FirstLevelOnly Then
        oBOM.StructuredViewFirstLevelOnly = True
    Else
        oBOM.StructuredViewFirstLevelOnly = False
    End If
    
    ' Make sure that the structured view is enabled.
    oBOM.StructuredViewEnabled = True
    
    'Set a reference to the "Structured" BOMView
    Dim oBOMView As bomView
    Set oBOMView = oBOM.BOMViews.Item("Structured")
    
    ' Inicializar Lin para comecar do indice 1 (0 e o cabecalho)
    Lin = 1
    
    ' Atualizar UserForm2 se estiver carregado
    Call SafeAddItemToListBox("Item", "Quantity", "Part Number", "Description", 0)
  
    
    Debug.Print "Item"; Tab(15); "Quantity"; Tab(30); "Part Number"; Tab(70); "Description"
    Debug.Print "----------------------------------------------------------------------------------"

    'Initialize the tab for ItemNumber
    Dim ItemTab As Long
    ItemTab = -3
    Call QueryBOMRowProperties(oBOMView.BOMRows, ItemTab)
End Sub

Private Sub QueryBOMRowProperties(oBOMRows As BOMRowsEnumerator, ItemTab As Long)
    ItemTab = ItemTab + 3
    ' Iterate through the contents of the BOM Rows.
    Dim i As Long
    For i = 1 To oBOMRows.Count
        ' Get the current row.
        Dim oRow As bomRow
        Set oRow = oBOMRows.Item(i)

        'Set a reference to the primary ComponentDefinition of the row
        Dim oCompDef As ComponentDefinition
        Set oCompDef = oRow.ComponentDefinitions.Item(1)

        Dim oPartNumProperty As Property
        Dim oDescripProperty As Property

        If TypeOf oCompDef Is VirtualComponentDefinition Then
            'Get the file property that contains the "Part Number"
            'The file property is obtained from the virtual component definition
            Set oPartNumProperty = oCompDef.PropertySets _
                .Item("Design Tracking Properties").Item("Part Number")

            'Get the file property that contains the "Description"
            Set oDescripProperty = oCompDef.PropertySets _
                .Item("Design Tracking Properties").Item("Description")
                
                

            Debug.Print Tab(ItemTab); oRow.ItemNumber; Tab(17); oRow.itemQuantity; Tab(30); _
                oPartNumProperty.Value; Tab(70); oDescripProperty.Value
            
            ' Atualizar UserForm2 se estiver carregado
            Call SafeAddItemToListBox(CStr(oRow.ItemNumber), CStr(oRow.itemQuantity), _
                CStr(oPartNumProperty.Value), CStr(oDescripProperty.Value), Lin)
            Lin = Lin + 1
        Else
           
            'Get the file property that contains the "Part Number"
            'The file property is obtained from the parent
            'document of the associated ComponentDefinition.
            Set oPartNumProperty = oCompDef.Document.PropertySets _
                .Item("Design Tracking Properties").Item("Part Number")

            'Get the file property that contains the "Description"
            Set oDescripProperty = oCompDef.Document.PropertySets _
                .Item("Design Tracking Properties").Item("Description")
         
            ' Atualizar UserForm2 se estiver carregado
            Call SafeAddItemToListBox(CStr(oRow.ItemNumber), CStr(oRow.itemQuantity), _
                CStr(oPartNumProperty.Value), CStr(oDescripProperty.Value), Lin)
            Lin = Lin + 1
                    
            Debug.Print Tab(ItemTab); oRow.ItemNumber; Tab(17); oRow.itemQuantity; Tab(30); _
                oPartNumProperty.Value; Tab(70); oDescripProperty.Value
              
               
            '; Tab(17); oRow.itemQuantity; Tab(30); _
            '    oPartNumProperty.Value; Tab(70); oDescripProperty.Value
            'Recursively iterate child rows if present.
            If Not oRow.ChildRows Is Nothing Then
                Call QueryBOMRowProperties(oRow.ChildRows, ItemTab)
            End If
        End If
    Next
    ItemTab = ItemTab - 3
End Sub

