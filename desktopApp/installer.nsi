; GemExportador NSIS Installer
; PostgreSQL embutido no instalador - sem download em runtime

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
!ifndef ICON_FILE
  !define ICON_FILE "src\jvmMain\resources\favicon.ico"
!endif
!ifndef PGSQL_DIR
  !define PGSQL_DIR "pgsql-bundle\pgsql"
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
!define MUI_ICON "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"

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
  File "/oname=${APP_NAME}.ico" "${ICON_FILE}"

  ; Diretorio app (JARs, DLLs, resources, config)
  SetOutPath "$INSTDIR\app"
  File /r "${APP_DIR}\app\*.*"

  ; Diretorio runtime (JRE com javaw.exe injetado)
  SetOutPath "$INSTDIR\runtime"
  File /r "${APP_DIR}\runtime\*.*"

  ; Scripts (processar-inventor.vbs e outros)
  SetOutPath "$INSTDIR\scripts"
  File /r "..\scripts\*.*"

  SetOutPath "$INSTDIR"

  ; ============================================
  ; PostgreSQL embutido - copia binarios
  ; ============================================
  DetailPrint "Instalando PostgreSQL..."
  CreateDirectory "C:\gem-exportador"
  CreateDirectory "C:\gem-exportador\logs"
  CreateDirectory "C:\gem-exportador\controle"

  ; Copia binarios PostgreSQL (somente se nao existem)
  IfFileExists "C:\gem-exportador\pgsql\bin\initdb.exe" pgsql_exists
    SetOutPath "C:\gem-exportador\pgsql"
    File /r "${PGSQL_DIR}\*.*"
  pgsql_exists:

  SetOutPath "$INSTDIR"

  ; .env
  FileOpen $0 "$INSTDIR\.env" w
  FileWrite $0 'SERVER_HOST=127.0.0.1$\r$\n'
  FileWrite $0 'SERVER_PORT=8080$\r$\n'
  FileWrite $0 'SERVER_URL=http://localhost:8080$\r$\n'
  FileWrite $0 'INVENTOR_PASTA_CONTROLE=C:\gem-exportador\controle$\r$\n'
  FileWrite $0 'LOG_LEVEL=INFO$\r$\n'
  FileWrite $0 'LOG_DIR=C:\gem-exportador\logs$\r$\n'
  FileWrite $0 '$\r$\n'
  FileWrite $0 '# PostgreSQL$\r$\n'
  FileWrite $0 'DB_HOST=localhost$\r$\n'
  FileWrite $0 'DB_PORT=5432$\r$\n'
  FileWrite $0 'DB_NAME=gem_exportador$\r$\n'
  FileWrite $0 'DB_USER=postgres$\r$\n'
  FileWrite $0 'DB_PASSWORD=123$\r$\n'
  FileClose $0

  ; Script de setup
  File "/oname=setup-postgres.cmd" "setup-postgres.cmd"

  ; Configura PostgreSQL (init, servico, banco)
  DetailPrint "Configurando PostgreSQL..."
  nsExec::ExecToLog '"$INSTDIR\setup-postgres.cmd"'
  Pop $0
  StrCmp $0 "0" pg_ok
    DetailPrint "Aviso: Setup PostgreSQL retornou codigo $0"
  pg_ok:

  ; Script de lancamento
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

  ; Shortcuts
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" \
    "$INSTDIR\launch.cmd" "" \
    "$INSTDIR\${APP_NAME}.ico" 0 \
    SW_SHOWMINIMIZED

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
    "$INSTDIR\launch.cmd" "" \
    "$INSTDIR\${APP_NAME}.ico" 0 \
    SW_SHOWMINIMIZED
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Desinstalar ${APP_NAME}.lnk" \
    "$INSTDIR\uninstall.exe"

  ; Registro
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
  ; Para o servico PostgreSQL
  nsExec::ExecToLog 'net stop GemPostgreSQL'
  nsExec::ExecToLog '"C:\gem-exportador\pgsql\bin\pg_ctl.exe" unregister -N GemPostgreSQL'

  ; Remove arquivos do app
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\runtime"
  Delete "$INSTDIR\${APP_NAME}.ico"
  Delete "$INSTDIR\launch.cmd"
  Delete "$INSTDIR\setup-postgres.cmd"
  Delete "$INSTDIR\.env"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  
  ; Pergunta se deseja remover dados
  MessageBox MB_YESNO|MB_ICONQUESTION "Deseja remover TODOS os dados (banco de dados, logs, PostgreSQL)?" IDYES removedata IDNO skipdata
  removedata:
    RMDir /r "C:\gem-exportador"
  skipdata:

  ; Remove ODBC DSN
  nsExec::ExecToLog 'powershell -Command "Remove-OdbcDsn -Name gem_exportador -DsnType System -Platform 32-bit -ErrorAction SilentlyContinue"'
  nsExec::ExecToLog 'powershell -Command "Remove-OdbcDsn -Name gem_exportador -DsnType System -Platform 64-bit -ErrorAction SilentlyContinue"'

  ; Remove shortcuts
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  ; Remove registro
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
  DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd

; --- Funcao para lancar o app ---
Function LaunchApp
  SetOutPath "$INSTDIR"
  Exec '"$INSTDIR\launch.cmd"'
FunctionEnd
