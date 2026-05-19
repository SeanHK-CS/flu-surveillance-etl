# Full pipeline: fetch -> clean -> validate
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "=== 1/4 CDC FluView ===" -ForegroundColor Cyan
python -m ingest.fetch_cdc

Write-Host "`n=== 2/4 HHS Hospital ===" -ForegroundColor Cyan
python -m ingest.fetch_hhs

Write-Host "`n=== 3/4 Build curated CSVs ===" -ForegroundColor Cyan
python -m transform.build_curated

Write-Host "`n=== 4/4 Validate outputs ===" -ForegroundColor Cyan
python scripts/validate_curated.py

Write-Host "`nReady for Power BI: data/curated/*.csv" -ForegroundColor Green
