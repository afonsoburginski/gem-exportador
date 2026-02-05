; GemExportador NSIS Installer
; Substitui jpackage MSI que gerava launcher com manifest corrompido

!include "MUI2.nsh"

; --- Defines (passados pelo Gradle via /D) ---
!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!ifndef APP_NAME
  !define APP_NAME "GemExportador"
!endif
!ifndef APP_DIR
  !define APP_DIR "build\compose\binaries\main\app\GemExportador"
!endif
!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "build\compose\binaries\main\nsis"
!endif

; --- Configuracao geral ---
Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUTPUT_DIR}\${APP_NAME}-${APP_VERSION}-setup.exe"
InstallDir "$PROGRAMFILES\${APP_NAME}"
InstallDirRegKey HKLM "Software\${APP_NAME}" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

; --- Interface ---
!define MUI_ABORTWARNING
!define MUI_ICON "${APP_DIR}\${APP_NAME}.ico"
!define MUI_UNICON "${APP_DIR}\${APP_NAME}.ico"

; --- Paginas do instalador ---
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION "LaunchApp"
!insertmacro MUI_PAGE_FINISH

; --- Paginas do desinstalador ---
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; --- Idioma ---
!insertmacro MUI_LANGUAGE "PortugueseBR"

; --- Funcao para desinstalar versao anterior ---
Function .onInit
  ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString"
  StrCmp $0 "" done
  MessageBox MB_YESNO|MB_ICONQUESTION "Uma versao anterior do ${APP_NAME} foi encontrada. Deseja desinstalar antes de continuar?" IDYES uninst IDNO done
  uninst:
    ExecWait '"$0" /S'
  done:
FunctionEnd

; --- Secao de instalacao ---
Section "Install"
  SetOutPath "$INSTDIR"

  ; Icone do app
  File "${APP_DIR}\${APP_NAME}.ico"

  ; Diretorio app (JARs, DLLs, resources, config)
  SetOutPath "$INSTDIR\app"
  File /r "${APP_DIR}\app\*.*"

  ; Diretorio runtime (JRE com javaw.exe injetado)
  SetOutPath "$INSTDIR\runtime"
  File /r "${APP_DIR}\runtime\*.*"

  ; Volta para INSTDIR (working dir dos shortcuts)
  SetOutPath "$INSTDIR"

  ; Cria script de lancamento (evita limite de 260 chars em shortcut)
  FileOpen $0 "$INSTDIR\launch.cmd" w
  FileWrite $0 '@echo off$\r$\n'
  FileWrite $0 'cd /d "%~dp0"$\r$\n'
  FileWrite $0 'start "" "runtime\bin\javaw.exe" ^$\r$\n'
  FileWrite $0 '  --add-opens java.desktop/sun.awt=ALL-UNNAMED ^$\r$\n'
  FileWrite $0 '  --add-opens java.desktop/java.awt.peer=ALL-UNNAMED ^$\r$\n'
  FileWrite $0 '  -Dskiko.library.path="app" ^$\r$\n'
  FileWrite $0 '  -Dcompose.application.resources.dir="app\resources" ^$\r$\n'
  FileWrite $0 '  -Dcompose.application.configure.swing.globals=true ^$\r$\n'
  FileWrite $0 '  -Djpackage.app-version=${APP_VERSION} ^$\r$\n'
  FileWrite $0 '  -cp "app\*" MainKt$\r$\n'
  FileClose $0

  ; Desinstalador
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Shortcut no Desktop (aponta para cmd minimizado, com icone correto)
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" \
    "$INSTDIR\launch.cmd" "" \
    "$INSTDIR\${APP_NAME}.ico" 0 \
    SW_SHOWMINNOACTIVE

  ; Shortcuts no Menu Iniciar
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
    "$INSTDIR\launch.cmd" "" \
    "$INSTDIR\${APP_NAME}.ico" 0 \
    SW_SHOWMINNOACTIVE
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Desinstalar ${APP_NAME}.lnk" \
    "$INSTDIR\uninstall.exe"

  ; Registro - Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "Publisher" "JhonRob"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "DisplayIcon" '"$INSTDIR\${APP_NAME}.ico"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
    "NoRepair" 1
  WriteRegStr HKLM "Software\${APP_NAME}" "InstallDir" "$INSTDIR"
SectionEnd

; --- Secao de desinstalacao ---
Section "Uninstall"
  ; Remove arquivos
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\runtime"
  Delete "$INSTDIR\${APP_NAME}.ico"
  Delete "$INSTDIR\launch.cmd"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  ; Remove shortcuts
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; Remove registro
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
  DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd

; --- Funcao para lancar o app apos instalacao ---
Function LaunchApp
  SetOutPath "$INSTDIR"
  Exec '"$INSTDIR\launch.cmd"'
FunctionEnd
