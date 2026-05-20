# Full pipeline: bronze -> curated CSVs -> Postgres star schema
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $env:POSTGRES_URL) {
    Write-Host "Set POSTGRES_URL or run docker/start_postgres.ps1 first" -ForegroundColor Yellow
}

Write-Host "=== 1/5 CDC ===" -ForegroundColor Cyan
python -m ingest.fetch_cdc

Write-Host "`n=== 2/5 HHS ===" -ForegroundColor Cyan
python -m ingest.fetch_hhs

Write-Host "`n=== 3/5 Curated CSVs ===" -ForegroundColor Cyan
python -m transform.build_curated

Write-Host "`n=== 4/5 Postgres warehouse ===" -ForegroundColor Cyan
python -m load.load_warehouse

Write-Host "`n=== 5/5 Smoke test (CSV + warehouse) ===" -ForegroundColor Cyan
python scripts/smoke_test.py --warehouse

Write-Host "`nDone. CSVs in data/curated; views in analytics.*" -ForegroundColor Green
