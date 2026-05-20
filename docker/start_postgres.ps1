# Start PostgreSQL for flu warehouse (feature/de-warehouse branch)
$ErrorActionPreference = "Stop"

$containerName = "flu-postgres"
$password = "fluwarehouse123"
$port = "5432"
$dbName = "flu_warehouse"

Write-Host "Checking Docker..." -ForegroundColor Cyan
docker ps 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

$exists = docker ps -a --filter "name=$containerName" --format "{{.Names}}"
function Wait-PostgresReady {
    param([string]$Name)
    for ($i = 1; $i -le 30; $i++) {
        docker exec $Name pg_isready -U postgres 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 2
    }
    Write-Host "Postgres did not become ready in time." -ForegroundColor Red
    exit 1
}

if ($exists -eq $containerName) {
    Write-Host "Starting existing container $containerName"
    docker start $containerName | Out-Null
    Wait-PostgresReady -Name $containerName
} else {
    Write-Host "Creating container $containerName"
    docker run -d `
        --name $containerName `
        -e POSTGRES_PASSWORD=$password `
        -e POSTGRES_DB=$dbName `
        -p "${port}:5432" `
        postgres:16 | Out-Null
    Write-Host "Waiting for Postgres to accept connections..."
    Wait-PostgresReady -Name $containerName
}

$env:POSTGRES_URL = "postgresql://postgres:${password}@localhost:${port}/${dbName}"
Write-Host "POSTGRES_URL=$env:POSTGRES_URL" -ForegroundColor Green
Write-Host "Run: .\run_pipeline_warehouse.ps1  (or: python -m load.load_warehouse)" -ForegroundColor Green
