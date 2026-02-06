@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

echo ============================================
echo   GEM Exportador - Setup PostgreSQL
echo ============================================
echo.

set PG_DIR=C:\gem-exportador\pgsql
set PG_DATA=%PG_DIR%\data
set PG_PORT=5432
set PG_USER=postgres
set PG_PASS=123
set PG_DB=gem_exportador
set SERVICE_NAME=GemPostgreSQL

:: ============================================
:: 1. Verifica se PostgreSQL ja esta rodando
:: ============================================
echo [1/5] Verificando PostgreSQL...

powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 (
    echo       PostgreSQL ja rodando na porta %PG_PORT%.
    goto :create_db
)

sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo       Servico encontrado. Iniciando...
    net start %SERVICE_NAME% >nul 2>&1
    timeout /t 5 /nobreak >nul
    goto :create_db
)

:: ============================================
:: 2. Verifica binarios
:: ============================================
echo [2/5] Verificando binarios PostgreSQL...

if not exist "%PG_DIR%\bin\initdb.exe" (
    echo       ERRO: Binarios PostgreSQL nao encontrados em %PG_DIR%\bin
    echo       Reinstale o GemExportador.
    exit /b 1
)
echo       Binarios OK em %PG_DIR%

:: ============================================
:: 3. Inicializar banco
:: ============================================
if exist "%PG_DATA%\PG_VERSION" (
    echo [3/5] Banco ja inicializado.
    goto :register_service
)

echo [3/5] Inicializando banco de dados...

:: Usa trust para local - sem problema de senha durante setup
"%PG_DIR%\bin\initdb.exe" -U %PG_USER% -A trust -E UTF-8 -D "%PG_DATA%" -L "%PG_DIR%\share"

if %errorlevel% neq 0 (
    echo       ERRO: Falha ao inicializar banco!
    exit /b 1
)

:: Configura postgresql.conf
echo. >> "%PG_DATA%\postgresql.conf"
echo # GEM Exportador >> "%PG_DATA%\postgresql.conf"
echo listen_addresses = '*' >> "%PG_DATA%\postgresql.conf"
echo port = %PG_PORT% >> "%PG_DATA%\postgresql.conf"
echo logging_collector = on >> "%PG_DATA%\postgresql.conf"
echo log_directory = 'log' >> "%PG_DATA%\postgresql.conf"

:: Configura pg_hba.conf - trust local, md5 remoto
echo. >> "%PG_DATA%\pg_hba.conf"
echo # Acesso remoto com senha >> "%PG_DATA%\pg_hba.conf"
echo host    all    all    0.0.0.0/0    md5 >> "%PG_DATA%\pg_hba.conf"

echo       Banco inicializado!

:: ============================================
:: 4. Registrar e iniciar servico
:: ============================================
:register_service
echo [4/5] Registrando servico Windows...

"%PG_DIR%\bin\pg_ctl.exe" register -N "%SERVICE_NAME%" -D "%PG_DATA%" -S auto >nul 2>&1
if %errorlevel% neq 0 (
    echo       Aviso: Servico ja pode estar registrado.
)

net start %SERVICE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo       Aviso: Tentando iniciar diretamente...
    start /b "" "%PG_DIR%\bin\pg_ctl.exe" start -D "%PG_DATA%" -l "%PG_DATA%\log\startup.log" -w
    timeout /t 5 /nobreak >nul
)

:: Aguarda ficar pronto (max 30 segundos)
set /a RETRIES=0
:wait_pg
set /a RETRIES+=1
if %RETRIES% gtr 15 (
    echo       ERRO: PostgreSQL nao iniciou em 30 segundos!
    echo       Verificando log...
    if exist "%PG_DATA%\log" (
        for /f "delims=" %%f in ('dir /b /o-d "%PG_DATA%\log\*.log" 2^>nul') do (
            type "%PG_DATA%\log\%%f" 2>nul
            goto :pg_failed
        )
    )
    :pg_failed
    exit /b 1
)
timeout /t 2 /nobreak >nul
powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% neq 0 goto :wait_pg

echo       PostgreSQL rodando na porta %PG_PORT%!

:: Firewall
netsh advfirewall firewall delete rule name="PostgreSQL GEM" >nul 2>&1
netsh advfirewall firewall add rule name="PostgreSQL GEM" dir=in action=allow protocol=TCP localport=%PG_PORT% >nul 2>&1

:: ============================================
:: 5. Criar banco e definir senha
:: ============================================
:create_db
echo [5/5] Criando banco '%PG_DB%'...

:: Define PGPASSWORD para conexoes que precisam
set PGPASSWORD=%PG_PASS%

:: Localiza psql
set PSQL=%PG_DIR%\bin\psql.exe
if not exist "%PSQL%" (
    where psql >nul 2>&1
    if %errorlevel% equ 0 (
        set PSQL=psql
    ) else (
        echo       psql nao encontrado - app criara o banco.
        goto :setup_odbc
    )
)

:: Tenta conectar (trust local nao precisa senha)
"%PSQL%" -U %PG_USER% -h 127.0.0.1 -p %PG_PORT% -d postgres -c "SELECT 1" >nul 2>&1
if %errorlevel% neq 0 (
    echo       Nao foi possivel conectar ao PostgreSQL.
    echo       App tentara criar o banco na primeira execucao.
    goto :setup_odbc
)

:: Define senha do usuario postgres
echo       Definindo senha do usuario postgres...
"%PSQL%" -U %PG_USER% -h 127.0.0.1 -p %PG_PORT% -d postgres -c "ALTER USER %PG_USER% PASSWORD '%PG_PASS%'" >nul 2>&1

:: Verifica se banco existe
"%PSQL%" -U %PG_USER% -h 127.0.0.1 -p %PG_PORT% -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='%PG_DB%'" 2>nul | findstr "1" >nul 2>&1
if %errorlevel% equ 0 (
    echo       Banco '%PG_DB%' ja existe.
) else (
    echo       Criando banco '%PG_DB%'...
    "%PSQL%" -U %PG_USER% -h 127.0.0.1 -p %PG_PORT% -d postgres -c "CREATE DATABASE %PG_DB%" 2>nul
    if !errorlevel! equ 0 (
        echo       Banco '%PG_DB%' criado com sucesso!
    ) else (
        echo       Aviso: Falha ao criar banco. App criara automaticamente.
    )
)

:: ============================================
:: ODBC DSN
:: ============================================
:setup_odbc
echo.
echo Configurando ODBC...
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI' -DsnType System -Platform '32-bit' -SetPropertyValue @('Server=localhost','Port=%PG_PORT%','Database=%PG_DB%','Username=%PG_USER%','Password=%PG_PASS%','SSLMode=disable') -ErrorAction Stop; Write-Host '      DSN 32-bit criado' } catch { Write-Host '      DSN 32-bit: driver ODBC nao encontrado (instale psqlodbc)' }" 2>nul
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI(x64)' -DsnType System -Platform '64-bit' -SetPropertyValue @('Server=localhost','Port=%PG_PORT%','Database=%PG_DB%','Username=%PG_USER%','Password=%PG_PASS%','SSLMode=disable') -ErrorAction Stop; Write-Host '      DSN 64-bit criado' } catch { Write-Host '      DSN 64-bit: driver ODBC nao encontrado (instale psqlodbc)' }" 2>nul

echo.
echo ============================================
echo   PostgreSQL pronto!
echo   Porta: %PG_PORT%  Banco: %PG_DB%
echo   Usuario: %PG_USER%  Senha: %PG_PASS%
echo ============================================

exit /b 0
