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
if ($exists -eq $containerName) {
    Write-Host "Starting existing container $containerName"
    docker start $containerName | Out-Null
} else {
    Write-Host "Creating container $containerName"
    docker run -d `
        --name $containerName `
        -e POSTGRES_PASSWORD=$password `
        -e POSTGRES_DB=$dbName `
        -p "${port}:5432" `
        postgres:16 | Out-Null
    Start-Sleep -Seconds 4
}

$env:POSTGRES_URL = "postgresql://postgres:${password}@localhost:${port}/${dbName}"
Write-Host "POSTGRES_URL=$env:POSTGRES_URL" -ForegroundColor Green
Write-Host "Run: python -m load.init_warehouse" -ForegroundColor Green
