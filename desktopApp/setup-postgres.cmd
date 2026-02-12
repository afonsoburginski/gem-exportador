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

:: URLs de download (ordem de prioridade)
set PG_URL_1=https://get.enterprisedb.com/postgresql/postgresql-16.6-1-windows-x64-binaries.zip
set PG_URL_2=https://get.enterprisedb.com/postgresql/postgresql-16.4-1-windows-x64-binaries.zip
set PG_URL_3=https://get.enterprisedb.com/postgresql/postgresql-17.2-1-windows-x64-binaries.zip
set PG_ZIP=C:\gem-exportador\pgsql-download.zip

:: ============================================
:: 1. Verifica se PostgreSQL ja esta rodando
:: ============================================
echo [1/6] Verificando PostgreSQL...

:: Verifica porta
powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 (
    echo       PostgreSQL ja rodando na porta %PG_PORT%.
    goto :create_db
)

:: Verifica servico GemPostgreSQL
sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    echo       Servico %SERVICE_NAME% encontrado. Iniciando...
    net start %SERVICE_NAME% >nul 2>&1
    timeout /t 5 /nobreak >nul
    powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 goto :create_db
)

:: Verifica servico postgresql padrao (instalacao existente)
sc query postgresql-x64-16 >nul 2>&1
if %errorlevel% equ 0 (
    echo       Servico postgresql-x64-16 encontrado. Iniciando...
    net start postgresql-x64-16 >nul 2>&1
    timeout /t 5 /nobreak >nul
    powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 goto :create_db
)

:: ============================================
:: 2. Download do PostgreSQL (se necessario)
:: ============================================
echo [2/6] Verificando binarios PostgreSQL...

if exist "%PG_DIR%\bin\initdb.exe" (
    echo       Binarios OK em %PG_DIR%
    goto :init_db
)

:: Verifica se ha pgsql dentro de subpasta (extracao com pasta intermediaria)
if exist "C:\gem-exportador\pgsql\pgsql\bin\initdb.exe" (
    echo       Corrigindo estrutura de pastas...
    robocopy "C:\gem-exportador\pgsql\pgsql" "%PG_DIR%" /E /MOVE /NFL /NDL /NJH /NJS >nul 2>&1
    if exist "%PG_DIR%\bin\initdb.exe" goto :init_db
)

echo       Binarios nao encontrados. Baixando PostgreSQL...
echo.

:: Cria diretorio
if not exist "C:\gem-exportador" mkdir "C:\gem-exportador"

:: Tenta cada URL
call :download_pg "%PG_URL_1%" "16.6-1"
if %errorlevel% equ 0 goto :extract_pg
call :download_pg "%PG_URL_2%" "16.4-1"
if %errorlevel% equ 0 goto :extract_pg
call :download_pg "%PG_URL_3%" "17.2-1"
if %errorlevel% equ 0 goto :extract_pg

echo       ERRO: Nao foi possivel baixar PostgreSQL de nenhuma URL!
echo       Resolucao manual:
echo         1. Baixe PostgreSQL 16 de: https://www.enterprisedb.com/download-postgresql-binaries
echo         2. Extraia para: %PG_DIR%
echo         3. Execute este script novamente
exit /b 1

:download_pg
set DL_URL=%~1
set DL_VER=%~2
echo       Tentando PostgreSQL %DL_VER%...
echo       URL: %DL_URL%

:: Tenta curl (mais confiavel no Windows 10+)
curl.exe -L -o "%PG_ZIP%" "%DL_URL%" --retry 2 --connect-timeout 15 -f -s 2>nul
if %errorlevel% equ 0 if exist "%PG_ZIP%" (
    for %%A in ("%PG_ZIP%") do set PG_SIZE=%%~zA
    if !PG_SIZE! gtr 50000000 (
        echo       Download OK: !PG_SIZE! bytes
        exit /b 0
    )
)
del /f /q "%PG_ZIP%" 2>nul

:: Tenta PowerShell WebClient
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { (New-Object Net.WebClient).DownloadFile('%DL_URL%', '%PG_ZIP%'); exit 0 } catch { exit 1 }" 2>nul
if %errorlevel% equ 0 if exist "%PG_ZIP%" (
    for %%A in ("%PG_ZIP%") do set PG_SIZE=%%~zA
    if !PG_SIZE! gtr 50000000 (
        echo       Download OK: !PG_SIZE! bytes
        exit /b 0
    )
)
del /f /q "%PG_ZIP%" 2>nul
echo       Falhou.
exit /b 1

:: ============================================
:: 2b. Extrai
:: ============================================
:extract_pg
echo       Extraindo para C:\gem-exportador...
powershell -Command "Expand-Archive -Path '%PG_ZIP%' -DestinationPath 'C:\gem-exportador' -Force" 2>nul
if %errorlevel% neq 0 (
    echo       ERRO: Falha ao extrair!
    del /f /q "%PG_ZIP%" 2>nul
    exit /b 1
)
del /f /q "%PG_ZIP%" 2>nul

:: A extracao pode criar C:\gem-exportador\pgsql\bin ou C:\gem-exportador\pgsql\pgsql\bin
if exist "%PG_DIR%\bin\initdb.exe" (
    echo       PostgreSQL extraido com sucesso!
    goto :init_db
)

:: Corrige pasta intermediaria (zip extrai para pgsql/ dentro do destino)
if exist "C:\gem-exportador\pgsql\pgsql\bin\initdb.exe" (
    echo       Corrigindo estrutura de pastas...
    :: Move conteudo de pgsql\pgsql para pgsql
    set TEMP_PG=C:\gem-exportador\_pgsql_temp
    ren "%PG_DIR%" _pgsql_temp
    ren "!TEMP_PG!\pgsql" pgsql
    move "C:\gem-exportador\pgsql" "C:\gem-exportador\" >nul 2>&1
    rd /s /q "!TEMP_PG!" 2>nul
    if exist "%PG_DIR%\bin\initdb.exe" (
        echo       Estrutura corrigida!
        goto :init_db
    )
)

:: Ultima tentativa: procura initdb.exe recursivamente
for /r "C:\gem-exportador" %%f in (initdb.exe) do (
    set FOUND_DIR=%%~dpf
    echo       Encontrado initdb.exe em !FOUND_DIR!
    if not "!FOUND_DIR!"=="%PG_DIR%\bin\" (
        echo       Movendo para %PG_DIR%...
        set PARENT_DIR=%%~dpf..
        robocopy "!PARENT_DIR!" "%PG_DIR%" /E /MOVE /NFL /NDL /NJH /NJS >nul 2>&1
    )
    goto :init_db
)

echo       ERRO: initdb.exe nao encontrado apos extracao!
exit /b 1

:: ============================================
:: 3. Inicializar banco
:: ============================================
:init_db
if exist "%PG_DATA%\PG_VERSION" (
    echo [3/6] Banco ja inicializado.
    goto :register_service
)

echo [3/6] Inicializando banco de dados...

:: Usa trust para local - sem problema de senha durante setup
"%PG_DIR%\bin\initdb.exe" -U %PG_USER% -A trust -E UTF-8 -D "%PG_DATA%" -L "%PG_DIR%\share"

if %errorlevel% neq 0 (
    echo       ERRO: Falha ao inicializar banco!
    echo       Tentando limpar e reinicializar...
    rd /s /q "%PG_DATA%" 2>nul
    "%PG_DIR%\bin\initdb.exe" -U %PG_USER% -A trust -E UTF-8 -D "%PG_DATA%" -L "%PG_DIR%\share"
    if !errorlevel! neq 0 (
        echo       ERRO: Falha na segunda tentativa de inicializacao!
        exit /b 1
    )
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
echo host    all    all    ::/0         md5 >> "%PG_DATA%\pg_hba.conf"

echo       Banco inicializado!

:: ============================================
:: 4. Registrar e iniciar servico
:: ============================================
:register_service
echo [4/6] Registrando servico Windows...

:: Desregistra versao antiga se existir (evita conflito)
"%PG_DIR%\bin\pg_ctl.exe" unregister -N "%SERVICE_NAME%" >nul 2>&1

:: Registra servico
"%PG_DIR%\bin\pg_ctl.exe" register -N "%SERVICE_NAME%" -D "%PG_DATA%" -S auto >nul 2>&1
if %errorlevel% neq 0 (
    echo       Aviso: Nao foi possivel registrar servico.
)

:: Inicia servico
net start %SERVICE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo       Aviso: net start falhou. Tentando pg_ctl diretamente...
    "%PG_DIR%\bin\pg_ctl.exe" start -D "%PG_DATA%" -l "%PG_DATA%\log\startup.log" -w >nul 2>&1
    timeout /t 5 /nobreak >nul
)

:: Aguarda ficar pronto (max 30 segundos)
set /a RETRIES=0
:wait_pg
set /a RETRIES+=1
if %RETRIES% gtr 15 (
    echo       AVISO: PostgreSQL nao respondeu em 30 segundos.
    echo       Tentando iniciar uma ultima vez...
    "%PG_DIR%\bin\pg_ctl.exe" restart -D "%PG_DATA%" -l "%PG_DATA%\log\startup.log" -w >nul 2>&1
    timeout /t 5 /nobreak >nul
    powershell -Command "try { $t = New-Object Net.Sockets.TcpClient('127.0.0.1',%PG_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
    if !errorlevel! neq 0 (
        echo       ERRO: PostgreSQL nao iniciou!
        if exist "%PG_DATA%\log" (
            echo       Ultimas linhas do log:
            for /f "delims=" %%f in ('dir /b /o-d "%PG_DATA%\log\*.log" 2^>nul') do (
                powershell -Command "Get-Content '%PG_DATA%\log\%%f' -Tail 10" 2>nul
                goto :pg_failed
            )
        )
        :pg_failed
        exit /b 1
    )
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
echo [5/6] Criando banco '%PG_DB%'...

set PGPASSWORD=%PG_PASS%

:: Localiza psql (nosso ou do sistema)
set PSQL=%PG_DIR%\bin\psql.exe
if not exist "%PSQL%" (
    :: Tenta psql no PATH
    where psql >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%p in ('where psql') do set PSQL=%%p
    ) else (
        echo       psql nao encontrado - app criara o banco automaticamente.
        goto :setup_odbc
    )
)

:: Tenta conectar (trust local primeiro, depois com senha)
"%PSQL%" -U %PG_USER% -h 127.0.0.1 -p %PG_PORT% -d postgres -c "SELECT 1" >nul 2>&1
if %errorlevel% neq 0 (
    :: Tenta sem host (socket local no Windows)
    "%PSQL%" -U %PG_USER% -p %PG_PORT% -d postgres -c "SELECT 1" >nul 2>&1
    if !errorlevel! neq 0 (
        echo       Nao foi possivel conectar ao PostgreSQL.
        echo       App tentara criar o banco na primeira execucao.
        goto :setup_odbc
    )
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
:: 6. ODBC DSN
:: ============================================
:setup_odbc
echo [6/6] Configurando ODBC...
powershell -Command "try { Remove-OdbcDsn -Name '%PG_DB%' -DsnType System -Platform '32-bit' -ErrorAction SilentlyContinue } catch {}" 2>nul
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI' -DsnType System -Platform '32-bit' -SetPropertyValue @('Server=localhost','Port=%PG_PORT%','Database=%PG_DB%','Username=%PG_USER%','Password=%PG_PASS%','SSLMode=disable') -ErrorAction Stop; Write-Host '      DSN 32-bit criado' } catch { Write-Host '      DSN 32-bit: driver ODBC nao encontrado (instale psqlodbc)' }" 2>nul
powershell -Command "try { Remove-OdbcDsn -Name '%PG_DB%' -DsnType System -Platform '64-bit' -ErrorAction SilentlyContinue } catch {}" 2>nul
powershell -Command "try { Add-OdbcDsn -Name '%PG_DB%' -DriverName 'PostgreSQL ANSI(x64)' -DsnType System -Platform '64-bit' -SetPropertyValue @('Server=localhost','Port=%PG_PORT%','Database=%PG_DB%','Username=%PG_USER%','Password=%PG_PASS%','SSLMode=disable') -ErrorAction Stop; Write-Host '      DSN 64-bit criado' } catch { Write-Host '      DSN 64-bit: driver ODBC nao encontrado (instale psqlodbc)' }" 2>nul

echo.
echo ============================================
echo   PostgreSQL pronto!
echo   Porta: %PG_PORT%  Banco: %PG_DB%
echo   Usuario: %PG_USER%  Senha: %PG_PASS%
echo ============================================

exit /b 0
