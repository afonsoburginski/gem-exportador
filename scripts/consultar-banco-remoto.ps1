# Consulta ao PostgreSQL em 192.168.1.116 (banco gem_exportador)
# Verifica quantos registros existem por computador (ex: JUNIOR VENSON)
# Requer: PostgreSQL ODBC Driver instalado OU psql no PATH

$HostDB = "192.168.1.116"
$Port = "5432"
$DbName = "gem_exportador"
$User = "postgres"
$Password = "123"

$Queries = @(
    @{
        Name = "Total de desenhos no banco"
        Sql = "SELECT COUNT(*) AS total FROM desenho;"
    },
    @{
        Name = "Desenhos por computador (ordenado por total)"
        Sql = "SELECT computador, COUNT(*) AS total FROM desenho GROUP BY computador ORDER BY total DESC;"
    },
    @{
        Name = "Desenhos do JUNIOR VENSON"
        Sql = "SELECT computador, COUNT(*) AS total FROM desenho WHERE computador ILIKE '%VENSON%' OR computador ILIKE '%JUNIOR%' GROUP BY computador;"
    },
    @{
        Name = "Ultimos 35 desenhos (id, nome_arquivo, computador, horario_envio)"
        Sql = "SELECT id, nome_arquivo, computador, horario_envio FROM desenho ORDER BY horario_envio DESC LIMIT 35;"
    }
)

# Tentativa 1: psql (PostgreSQL client)
$psql = Get-Command psql -ErrorAction SilentlyContinue
if ($psql) {
    $env:PGPASSWORD = $Password
    Write-Host "=== Usando psql para $HostDB`:$Port/$DbName ===" -ForegroundColor Cyan
    foreach ($q in $Queries) {
        Write-Host "`n--- $($q.Name) ---" -ForegroundColor Yellow
        & psql -h $HostDB -p $Port -U $User -d $DbName -t -A -c $q.Sql 2>&1
    }
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    exit 0
}

# Tentativa 2: ODBC (PostgreSQL Unicode/ANSI driver)
try {
    $connStr = "Driver={PostgreSQL Unicode};Server=$HostDB;Port=$Port;Database=$DbName;Uid=$User;Pwd=$Password;"
    $conn = New-Object System.Data.Odbc.OdbcConnection($connStr)
    $conn.Open()
    Write-Host "=== Conexao ODBC OK com $HostDB ===" -ForegroundColor Green
    foreach ($q in $Queries) {
        Write-Host "`n--- $($q.Name) ---" -ForegroundColor Yellow
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $q.Sql
        $rd = $cmd.ExecuteReader()
        while ($rd.Read()) {
            $row = @()
            for ($i = 0; $i -lt $rd.FieldCount; $i++) { $row += $rd.GetValue($i) }
            Write-Host ($row -join " | ")
        }
        $rd.Close()
    }
    $conn.Close()
    exit 0
} catch {
    Write-Host "ODBC (PostgreSQL Unicode) falhou: $_" -ForegroundColor Red
}

# Tentativa 3: ODBC com nome alternativo do driver
try {
    $connStr = "Driver={PostgreSQL ANSI};Server=$HostDB;Port=$Port;Database=$DbName;Uid=$User;Pwd=$Password;"
    $conn = New-Object System.Data.Odbc.OdbcConnection($connStr)
    $conn.Open()
    Write-Host "=== Conexao ODBC (ANSI) OK com $HostDB ===" -ForegroundColor Green
    foreach ($q in $Queries) {
        Write-Host "`n--- $($q.Name) ---" -ForegroundColor Yellow
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $q.Sql
        $rd = $cmd.ExecuteReader()
        while ($rd.Read()) {
            $row = @()
            for ($i = 0; $i -lt $rd.FieldCount; $i++) { $row += $rd.GetValue($i) }
            Write-Host ($row -join " | ")
        }
        $rd.Close()
    }
    $conn.Close()
    exit 0
} catch {
    Write-Host "ODBC (PostgreSQL ANSI) falhou: $_" -ForegroundColor Red
}

Write-Host "`nNenhum metodo disponivel. Instale:" -ForegroundColor Red
Write-Host "  - PostgreSQL (binarios) e use psql, ou"
Write-Host "  - PostgreSQL ODBC Driver (psqlODBC) e execute este script de novo."
Write-Host "  Drivers ODBC instalados:" -ForegroundColor Gray
Get-OdbcDriver | Where-Object { $_.Name -like "*PostgreSQL*" } | ForEach-Object { Write-Host "    $($_.Name)" }
