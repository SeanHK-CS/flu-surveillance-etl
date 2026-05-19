# PostgreSQL Database Setup Script
# This script helps you set up a PostgreSQL database for the Influenza Surveillance ETL

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PostgreSQL Database Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available
$dockerAvailable = $false
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerAvailable = $true
        Write-Host "[OK] Docker is installed" -ForegroundColor Green
    }
} catch {
    Write-Host "[INFO] Docker not available" -ForegroundColor Yellow
}

# Option 1: Docker (if available)
if ($dockerAvailable) {
    Write-Host ""
    Write-Host "Option 1: Use Docker (Recommended - Fastest)" -ForegroundColor Yellow
    Write-Host "This will start PostgreSQL in a Docker container." -ForegroundColor Gray
    $useDocker = Read-Host "Use Docker? (Y/N)"
    
    if ($useDocker -eq 'Y' -or $useDocker -eq 'y') {
        Write-Host ""
        Write-Host "Starting Docker PostgreSQL container..." -ForegroundColor Green
        
        # Check if container already exists
        $existingContainer = docker ps -a --filter "name=influenza-postgres" --format "{{.Names}}" 2>&1
        if ($existingContainer -like "*influenza-postgres*") {
            Write-Host "Container exists. Starting it..." -ForegroundColor Yellow
            docker start influenza-postgres
        } else {
            Write-Host "Creating new container..." -ForegroundColor Yellow
            docker run --name influenza-postgres `
                -e POSTGRES_PASSWORD=influenza123 `
                -e POSTGRES_DB=influenza_db `
                -p 5432:5432 `
                -d postgres:15
            
            Write-Host "Waiting for PostgreSQL to start..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        
        # Test connection
        Write-Host "Testing connection..." -ForegroundColor Green
        $testResult = docker exec influenza-postgres psql -U postgres -d influenza_db -c "SELECT version();" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] PostgreSQL is running!" -ForegroundColor Green
            $env:POSTGRES_URL = "postgresql://postgres:influenza123@localhost:5432/influenza_db"
            Write-Host ""
            Write-Host "Connection string set:" -ForegroundColor Green
            Write-Host "POSTGRES_URL=$env:POSTGRES_URL" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Create tables: Run the SQL scripts in sql/ folder" -ForegroundColor White
            Write-Host "2. Test ingestion: python run_google_trends_test.py" -ForegroundColor White
            exit 0
        } else {
            Write-Host "[ERROR] Could not connect. Docker Desktop may not be running." -ForegroundColor Red
            Write-Host "Please start Docker Desktop and run this script again." -ForegroundColor Yellow
        }
    }
}

# Option 2: Manual setup
Write-Host ""
Write-Host "Option 2: Manual Database Configuration" -ForegroundColor Yellow
Write-Host "If you have PostgreSQL installed locally or a remote database:" -ForegroundColor Gray
Write-Host ""

$dbHost = Read-Host "Database host (default: localhost)"
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = "localhost" }

$dbPort = Read-Host "Database port (default: 5432)"
if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = "5432" }

$dbName = Read-Host "Database name (default: influenza_db)"
if ([string]::IsNullOrWhiteSpace($dbName)) { $dbName = "influenza_db" }

$dbUser = Read-Host "Database user (default: postgres)"
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "postgres" }

$dbPassword = Read-Host "Database password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
$dbPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Build connection string
$connectionString = "postgresql://${dbUser}:${dbPasswordPlain}@${dbHost}:${dbPort}/${dbName}"

# Set environment variable
$env:POSTGRES_URL = $connectionString

Write-Host ""
Write-Host "Connection string configured:" -ForegroundColor Green
Write-Host "POSTGRES_URL=$connectionString" -ForegroundColor Cyan
Write-Host ""

# Test connection
Write-Host "Testing connection..." -ForegroundColor Yellow
try {
    # Try using psql if available
    $psqlPath = Get-Command psql -ErrorAction SilentlyContinue
    if ($psqlPath) {
        $testResult = psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -c "SELECT version();" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Connection successful!" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Connection test failed, but environment variable is set." -ForegroundColor Yellow
            Write-Host "You can proceed and test with the Python script." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[INFO] psql not found. Environment variable is set." -ForegroundColor Yellow
        Write-Host "You can test the connection with the Python script." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[INFO] Could not test connection automatically." -ForegroundColor Yellow
    Write-Host "Environment variable is set. Test with: python run_google_trends_test.py" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To make this permanent, add to your PowerShell profile:" -ForegroundColor Yellow
Write-Host '$env:POSTGRES_URL="' + $connectionString + '"' -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Create database tables (if not done)" -ForegroundColor White
Write-Host "2. Run: python run_google_trends_test.py" -ForegroundColor White
