VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} UserForm1 
   Caption         =   "JHONROB SILOS E SECADORES LTDA"
   ClientHeight    =   5370
   ClientLeft      =   105
   ClientTop       =   450
   ClientWidth     =   7350
   OleObjectBlob   =   "UserForm1.frx":0000
   StartUpPosition =   1  'CenterOwner
End
Attribute VB_Name = "UserForm1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Private Sub CommandButton1_Click()
ExportarParaDWG
End Sub

Private Sub CommandButton2_Click()
ExportarParaPDF
End Sub

Private Sub CommandButton3_Click()
ExportarIDWtoDWF
End Sub

Private Sub CommandButton4_Click()
UserForm1.Label2.caption = ""
UserForm1.Label3.caption = ""
UserForm1.Label4.caption = ""
UserForm1.Label5.caption = ""
UserForm1.Label6.caption = ""

ExpTodos = True
DetectarTipoDeArquivoAberto
If TipoArquivo = "idw" Then
WriteSheetMetalDXF
ExportPartsListToCSV
Unload UserForm1
Else
MsgBox "A Opção de exportar todos é somente para arquivos .IDW com desenho aberto!", vbInformation, "JHONROB SILOS E SECADORES LTDA"
End If


End Sub

Private Sub CommandButton5_Click()
DetectarTipoDeArquivoAberto
WriteSheetMetalDXF
Unload UserForm1
End Sub

Private Sub CommandButton6_Click()
ExportPartsListToCSV
End Sub

Private Sub CommandButton7_Click()
DetectarTipoDeArquivoAberto
End Sub

Private Sub UserForm_Initialize()
UserForm1.Label2.caption = ""
UserForm1.Label3.caption = ""
UserForm1.Label4.caption = ""
UserForm1.Label5.caption = ""
UserForm1.Label6.caption = ""
UserForm1.Label7.caption = ""

End Sub
