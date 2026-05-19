# Docker PostgreSQL Setup Script with Learning Explanations
# This script will guide you through setting up PostgreSQL in Docker

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker PostgreSQL Setup & Learning" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if Docker is running
Write-Host "Step 1: Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Docker is installed: $dockerVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "  [ERROR] Docker not found. Please install Docker Desktop." -ForegroundColor Red
    Write-Host "  Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check if Docker daemon is running
Write-Host ""
Write-Host "Step 2: Checking if Docker Desktop is running..." -ForegroundColor Yellow
try {
    $containers = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Docker Desktop is running!" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Docker Desktop is not running." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please do the following:" -ForegroundColor Yellow
        Write-Host "  1. Open Docker Desktop from Start menu" -ForegroundColor White
        Write-Host "  2. Wait for it to fully start (whale icon in system tray)" -ForegroundColor White
        Write-Host "  3. Run this script again" -ForegroundColor White
        Write-Host ""
        Write-Host "  Or start it manually:" -ForegroundColor Yellow
        Write-Host "  Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "  [ERROR] Could not connect to Docker." -ForegroundColor Red
    exit 1
}

# Step 3: Check if container already exists
Write-Host ""
Write-Host "Step 3: Checking for existing container..." -ForegroundColor Yellow
$existingContainer = docker ps -a --filter "name=influenza-postgres" --format "{{.Names}}" 2>&1
if ($existingContainer -like "*influenza-postgres*") {
    Write-Host "  [INFO] Container 'influenza-postgres' already exists" -ForegroundColor Yellow
    
    # Check if it's running
    $running = docker ps --filter "name=influenza-postgres" --format "{{.Names}}" 2>&1
    if ($running -like "*influenza-postgres*") {
        Write-Host "  [OK] Container is already running!" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Starting existing container..." -ForegroundColor Yellow
        docker start influenza-postgres
        Start-Sleep -Seconds 3
        Write-Host "  [OK] Container started!" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Creating new PostgreSQL container..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  What this command does:" -ForegroundColor Cyan
    Write-Host "  - Creates a container named 'influenza-postgres'" -ForegroundColor Gray
    Write-Host "  - Sets database password to 'influenza123'" -ForegroundColor Gray
    Write-Host "  - Creates database 'influenza_db' automatically" -ForegroundColor Gray
    Write-Host "  - Maps port 5432 (host) to 5432 (container)" -ForegroundColor Gray
    Write-Host "  - Runs in background (-d flag)" -ForegroundColor Gray
    Write-Host ""
    
    docker run --name influenza-postgres `
        -e POSTGRES_PASSWORD=influenza123 `
        -e POSTGRES_DB=influenza_db `
        -p 5432:5432 `
        -d postgres:15
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [SUCCESS] Container created and started!" -ForegroundColor Green
        Write-Host "  [INFO] Waiting for PostgreSQL to initialize..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    } else {
        Write-Host "  [ERROR] Failed to create container" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Test connection
Write-Host ""
Write-Host "Step 4: Testing database connection..." -ForegroundColor Yellow
$testResult = docker exec influenza-postgres psql -U postgres -d influenza_db -c "SELECT version();" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [SUCCESS] Database is ready!" -ForegroundColor Green
    Write-Host "  Connection details:" -ForegroundColor Cyan
    Write-Host "    Host: localhost" -ForegroundColor Gray
    Write-Host "    Port: 5432" -ForegroundColor Gray
    Write-Host "    Database: influenza_db" -ForegroundColor Gray
    Write-Host "    User: postgres" -ForegroundColor Gray
    Write-Host "    Password: influenza123" -ForegroundColor Gray
} else {
    Write-Host "  [WARNING] Connection test failed, but container is running." -ForegroundColor Yellow
    Write-Host "  This might be normal - PostgreSQL may still be initializing." -ForegroundColor Yellow
    Write-Host "  Wait 10 seconds and try: docker exec influenza-postgres psql -U postgres -d influenza_db -c 'SELECT 1;'" -ForegroundColor Cyan
}

# Step 5: Set environment variable
Write-Host ""
Write-Host "Step 5: Setting environment variable..." -ForegroundColor Yellow
$env:POSTGRES_URL = "postgresql://postgres:influenza123@localhost:5432/influenza_db"
Write-Host "  [OK] POSTGRES_URL environment variable set" -ForegroundColor Green
Write-Host "  Value: $env:POSTGRES_URL" -ForegroundColor Cyan

# Step 6: Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "What you learned:" -ForegroundColor Yellow
Write-Host "  ✓ Docker container creation and management" -ForegroundColor White
Write-Host "  ✓ Port mapping (5432:5432)" -ForegroundColor White
Write-Host "  ✓ Environment variables in containers" -ForegroundColor White
Write-Host "  ✓ Executing commands in containers" -ForegroundColor White
Write-Host ""
Write-Host "Useful Docker commands to try:" -ForegroundColor Yellow
Write-Host "  docker ps                          # List running containers" -ForegroundColor Cyan
Write-Host "  docker logs influenza-postgres     # View container logs" -ForegroundColor Cyan
Write-Host "  docker stop influenza-postgres     # Stop container" -ForegroundColor Cyan
Write-Host "  docker start influenza-postgres    # Start container" -ForegroundColor Cyan
Write-Host "  docker exec -it influenza-postgres psql -U postgres -d influenza_db  # Interactive SQL" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Create database tables: python create_tables.py" -ForegroundColor White
Write-Host "  2. Test ingestion: python run_google_trends_test.py" -ForegroundColor White
Write-Host ""
Write-Host "Note: This environment variable is only for this PowerShell session." -ForegroundColor Gray
Write-Host "To make it permanent, add to your PowerShell profile." -ForegroundColor Gray
