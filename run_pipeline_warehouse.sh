#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${POSTGRES_URL:-}" ]]; then
  echo "Set POSTGRES_URL or run: docker/start_postgres.sh"
fi

echo "=== 1/5 CDC ==="
python -m ingest.fetch_cdc

echo ""
echo "=== 2/5 HHS ==="
python -m ingest.fetch_hhs

echo ""
echo "=== 3/5 Curated CSVs ==="
python -m transform.build_curated

echo ""
echo "=== 4/5 Postgres warehouse ==="
python -m load.load_warehouse

echo ""
echo "=== 5/5 Validate ==="
python scripts/smoke_test.py --warehouse

echo ""
echo "Done. CSVs in data/curated; views in analytics.*"
