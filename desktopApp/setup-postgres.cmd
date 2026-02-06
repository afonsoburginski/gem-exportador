@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

echo ============================================
echo   GEM Exportador - Setup PostgreSQL
echo ============================================
echo.

set PG_DIR=C:\gem-exportador\pgsql
set PG_DATA=C:\gem-exportador\pgsql\data
set PG_PORT=5432
set PG_USER=postgres
set PG_PASS=123
set PG_DB=gem_exportador
set SERVICE_NAME=GemPostgreSQL
set PG_URL=https://sbp.enterprisedb.com/getfile.jsp?fileid=1259906

:: ============================================
:: 1. Verifica se PostgreSQL ja esta acessivel
:: ============================================
echo [1/6] Verificando se PostgreSQL ja esta instalado...

:: Tenta conectar na porta 5432
powershell -Command "try { $tcp = New-Object System.Net.Sockets.TcpClient; $tcp.Connect('127.0.0.1', %PG_PORT%); $tcp.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 (
    echo       PostgreSQL ja esta rodando na porta %PG_PORT%!
    goto :create_db
)

:: Verifica se nosso servico existe
sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo       Servico %SERVICE_NAME% encontrado. Iniciando...
    net start %SERVICE_NAME% >nul 2>&1
    timeout /t 5 /nobreak >nul
    goto :create_db
)

:: Verifica se ja tem binarios instalados
if exist "%PG_DIR%\bin\pg_ctl.exe" (
    echo       Binarios PostgreSQL encontrados em %PG_DIR%
    if exist "%PG_DATA%\PG_VERSION" (
        echo       Dados do banco encontrados. Registrando servico...
        goto :register_service
    ) else (
        echo       Dados nao encontrados. Inicializando...
        goto :init_db
    )
)

:: ============================================
:: 2. Download PostgreSQL
:: ============================================
echo [2/6] Baixando PostgreSQL 16 (pode levar alguns minutos)...

:: Usa nome unico para evitar conflito com arquivo travado
set PG_ZIP=%TEMP%\pgsql-%RANDOM%%RANDOM%.zip

:: Tenta limpar downloads anteriores travados
del /f /q "%TEMP%\postgresql-binaries.zip" >nul 2>&1
del /f /q "%TEMP%\pgsql-*.zip" >nul 2>&1

echo       Baixando para %PG_ZIP%...
curl.exe -L -o "%PG_ZIP%" "%PG_URL%"
if %errorlevel% neq 0 (
    echo       ERRO: Falha ao baixar PostgreSQL!
    echo       Verifique sua conexao com a internet.
    exit /b 1
)

:: Verifica se o arquivo foi baixado e tem tamanho > 0
if not exist "%PG_ZIP%" (
    echo       ERRO: Arquivo nao foi baixado!
    exit /b 1
)

for %%A in ("%PG_ZIP%") do set FILE_SIZE=%%~zA
if "%FILE_SIZE%"=="0" (
    echo       ERRO: Arquivo baixado esta vazio!
    del /f "%PG_ZIP%" >nul 2>&1
    exit /b 1
)

echo       Download concluido (%FILE_SIZE% bytes)

:: ============================================
:: 3. Extrair PostgreSQL
:: ============================================
echo [3/6] Extraindo PostgreSQL...

:: Cria diretorio base
if not exist "C:\gem-exportador" mkdir "C:\gem-exportador"

:: Remove instalacao anterior se existir
if exist "%PG_DIR%" rmdir /s /q "%PG_DIR%"

:: Extrai o ZIP (estrutura: pgsql\bin, pgsql\share, etc.)
powershell -Command "Expand-Archive -Path '%PG_ZIP%' -DestinationPath 'C:\gem-exportador' -Force"
if %errorlevel% neq 0 (
    echo       ERRO: Falha ao extrair PostgreSQL!
    del /f "%PG_ZIP%" >nul 2>&1
    exit /b 1
)

:: Limpa o ZIP
del /f "%PG_ZIP%" >nul 2>&1

:: Verifica se extraiu corretamente
if not exist "%PG_DIR%\bin\initdb.exe" (
    echo       ERRO: Binarios nao encontrados apos extracao!
    echo       Verificando estrutura...
    dir "C:\gem-exportador" /b
    exit /b 1
)

echo       PostgreSQL extraido com sucesso!

:: ============================================
:: 4. Inicializar banco de dados
:: ============================================
:init_db
echo [4/6] Inicializando banco de dados...

:: Cria arquivo de senha (sem newline final)
> "%TEMP%\pgpass.txt" (
    <nul set /p=%PG_PASS%
)

"%PG_DIR%\bin\initdb.exe" -U %PG_USER% -A md5 --pwfile="%TEMP%\pgpass.txt" -E UTF-8 -D "%PG_DATA%" -L "%PG_DIR%\share"
set INIT_RESULT=%errorlevel%

del /f "%TEMP%\pgpass.txt" >nul 2>&1

if %INIT_RESULT% neq 0 (
    echo       ERRO: Falha ao inicializar banco!
    exit /b 1
)

:: Configura postgresql.conf para aceitar conexoes de rede
>> "%PG_DATA%\postgresql.conf" (
    echo.
    echo # GEM Exportador config
    echo listen_addresses = '*'
    echo port = %PG_PORT%
    echo logging_collector = on
    echo log_directory = 'log'
)

:: Configura pg_hba.conf para aceitar conexoes da rede local com senha
>> "%PG_DATA%\pg_hba.conf" (
    echo.
    echo # Acesso remoto da rede local (GEM Exportador)
    echo host    all    all    0.0.0.0/0    md5
)

echo       Banco inicializado com sucesso!

:: ============================================
:: 5. Registrar e iniciar servico Windows
:: ============================================
:register_service
echo [5/6] Registrando servico Windows '%SERVICE_NAME%'...

:: Registra como servico do Windows (inicia automaticamente)
"%PG_DIR%\bin\pg_ctl.exe" register -N "%SERVICE_NAME%" -D "%PG_DATA%" -S auto
if %errorlevel% neq 0 (
    echo       Aviso: Nao foi possivel registrar como servico.
    echo       Tentando iniciar manualmente...
    "%PG_DIR%\bin\pg_ctl.exe" start -D "%PG_DATA%" -w -t 30
) else (
    echo       Servico registrado! Iniciando...
    net start %SERVICE_NAME%
)

:: Aguarda PostgreSQL ficar pronto
echo       Aguardando PostgreSQL iniciar...
set /a RETRIES=0
:wait_pg
set /a RETRIES+=1
if %RETRIES% gtr 15 (
    echo       ERRO: PostgreSQL nao iniciou a tempo!
    exit /b 1
)
timeout /t 2 /nobreak >nul
powershell -Command "try { $tcp = New-Object System.Net.Sockets.TcpClient; $tcp.Connect('127.0.0.1', %PG_PORT%); $tcp.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% neq 0 goto :wait_pg

echo       PostgreSQL rodando!

:: Libera porta 5432 no Firewall do Windows (para acesso remoto)
netsh advfirewall firewall add rule name="PostgreSQL GEM" dir=in action=allow protocol=TCP localport=%PG_PORT% >nul 2>&1
echo       Firewall: porta %PG_PORT% liberada

:: ============================================
:: 6. Criar banco de dados
:: ============================================
:create_db
echo [6/6] Configurando banco de dados '%PG_DB%'...

:: Define senha para conexao
set PGPASSWORD=%PG_PASS%

:: Determina qual psql usar
set PSQL=%PG_DIR%\bin\psql.exe
if not exist "%PSQL%" (
    where psql >nul 2>&1
    if %errorlevel% equ 0 (
        set PSQL=psql
    ) else (
        echo       Aviso: psql nao encontrado. Banco sera criado pelo app.
        goto :setup_odbc
    )
)

:: Verifica se o banco ja existe
"%PSQL%" -U %PG_USER% -h localhost -p %PG_PORT% -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='%PG_DB%'" 2>nul | findstr "1" >nul 2>&1
if %errorlevel% equ 0 (
    echo       Banco '%PG_DB%' ja existe.
) else (
    :: Cria o banco
    "%PG_DIR%\bin\createdb.exe" -U %PG_USER% -h localhost -p %PG_PORT% %PG_DB% 2>nul
    if !errorlevel! equ 0 (
        echo       Banco '%PG_DB%' criado com sucesso!
    ) else (
        echo       Aviso: Nao foi possivel criar banco. O app criara automaticamente.
    )
)

:: ============================================
:: 7. Configurar ODBC DSN (opcional)
:: ============================================
:setup_odbc
echo.
echo [Extra] Configurando ODBC DSN...

:: Tenta criar DSN de sistema (32-bit) para o banco
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI' -DsnType System -Platform '32-bit' -SetPropertyValue @('Server=localhost', 'Port=%PG_PORT%', 'Database=%PG_DB%', 'Username=%PG_USER%', 'Password=%PG_PASS%', 'SSLMode=disable') -ErrorAction Stop; Write-Host '       DSN ODBC 32-bit criado!'; exit 0 } catch { Write-Host '       Aviso: Driver ODBC nao encontrado (instale psqlODBC separadamente)'; exit 0 }" 2>nul

:: Tenta tambem 64-bit
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI(x64)' -DsnType System -Platform '64-bit' -SetPropertyValue @('Server=localhost', 'Port=%PG_PORT%', 'Database=%PG_DB%', 'Username=%PG_USER%', 'Password=%PG_PASS%', 'SSLMode=disable') -ErrorAction Stop; Write-Host '       DSN ODBC 64-bit criado!'; exit 0 } catch { exit 0 }" 2>nul

echo.
echo ============================================
echo   PostgreSQL configurado com sucesso!
echo.
echo   Host:     localhost
echo   Porta:    %PG_PORT%
echo   Banco:    %PG_DB%
echo   Usuario:  %PG_USER%
echo   Senha:    %PG_PASS%
echo   Servico:  %SERVICE_NAME%
echo ============================================
echo.

exit /b 0
