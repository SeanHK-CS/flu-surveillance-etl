"""Shared paths for bronze (raw) and silver (curated) data."""
from datetime import date
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
CURATED_DIR = DATA_DIR / "curated"


def run_date() -> str:
    return date.today().isoformat()


def raw_run_dir(source: str) -> Path:
    path = RAW_DIR / source / run_date()
    path.mkdir(parents=True, exist_ok=True)
    return path
