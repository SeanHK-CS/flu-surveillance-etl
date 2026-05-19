#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== 1/4 CDC FluView ==="
python -m ingest.fetch_cdc

echo ""
echo "=== 2/4 HHS Hospital ==="
python -m ingest.fetch_hhs

echo ""
echo "=== 3/4 Build curated CSVs ==="
python -m transform.build_curated

echo ""
echo "=== 4/4 Validate outputs ==="
python scripts/validate_curated.py

echo ""
echo "Ready for Power BI: data/curated/*.csv"
