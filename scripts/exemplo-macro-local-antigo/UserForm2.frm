VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} UserForm2 
   Caption         =   "UserForm2"
   ClientHeight    =   7392
   ClientLeft      =   105
   ClientTop       =   450
   ClientWidth     =   14385
   OleObjectBlob   =   "UserForm2.frx":0000
   ShowModal       =   0   'False
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "UserForm2"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Private Sub CommandButton1_Click()
UserForm2.ListBox1.Clear
Lin = Empty
BOMQuery
End Sub

Private Sub ListBox1_Click()

End Sub




Private Sub UserForm_Initialize()

    ' Adicionar itens ao ListBox em múltiplas colunas
    'ListBox1.ColumnWidths = "100;100;100"  ' Definir largura das colunas
    'ListBox1.ColumnCount = 3  ' Definir número de colunas
    
    ' Adicionar itens manualmente (simulação de colunas)
    'ListBox1.AddItem "Item 1;Valor 1;Descrição 1"
    'ListBox1.AddItem "Item 2;Valor 2;Descrição 2"
    'ListBox1.AddItem "Item 3;Valor 3;Descrição 3"
    'ListBox1.AddItem "Item 4;Valor 4;Descrição 4"
    'ListBox1.AddItem "Item 5;Valor 5;Descrição 5"
End Sub

