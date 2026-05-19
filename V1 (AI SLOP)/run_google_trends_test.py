"""
Quick test script for Google Trends ingestion.
Tests with a single state first before running full ingestion.
"""

import os
import sys
from datetime import datetime, timedelta

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from ingest_google_trends import GoogleTrendsIngester
    print("[OK] Successfully imported GoogleTrendsIngester")
except ImportError as e:
    print(f"[ERROR] Import error: {e}")
    print("Make sure you're in the project root directory")
    sys.exit(1)

# Check environment variables
print("\n=== Environment Check ===")
db_url = os.getenv('POSTGRES_URL') or os.getenv('DATABASE_CONNECTION_STRING')
if not db_url:
    print("[WARNING] POSTGRES_URL not set. Using default.")
    print("Set it with: $env:POSTGRES_URL='postgresql://user:password@localhost:5432/influenza_db'")
    db_url = "postgresql://user:password@localhost:5432/influenza_db"
else:
    print(f"[OK] Database URL configured")

print(f"[OK] Staging schema: {os.getenv('STAGING_SCHEMA', 'staging')}")
print(f"[OK] Log directory: {os.getenv('LOG_DIR', 'logs')}")

# Test with single state
print("\n=== Running Test (California, last 7 days) ===")
print("This will test the ingestion with just one state to verify everything works.")
print("Press Ctrl+C to cancel, or wait 10 seconds to continue...")

try:
    import time
    time.sleep(10)
except KeyboardInterrupt:
    print("\nCancelled by user")
    sys.exit(0)

try:
    ingester = GoogleTrendsIngester()
    
    # Test with just California, last 7 days
    test_states = ['US-CA']
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    print(f"\nFetching Google Trends data for California from {start_date.date()} to {end_date.date()}")
    print("This may take 10-30 seconds...\n")
    
    success = ingester.run_ingestion(
        start_date=start_date,
        end_date=end_date,
        states=test_states
    )
    
    if success:
        print("\n" + "="*60)
        print("[SUCCESS] TEST SUCCESSFUL!")
        print("="*60)
        print("\nNext steps:")
        print("1. Check staging table: SELECT COUNT(*) FROM staging.google_trends_raw;")
        print("2. Transform to facts: SELECT * FROM transform.load_google_trends_to_facts();")
        print("3. Calculate metrics: SELECT * FROM transform.update_search_interest_rolling_averages();")
        print("\nTo run full ingestion for all states:")
        print("  python src/ingest_google_trends.py")
    else:
        print("\n" + "="*60)
        print("[FAILED] TEST FAILED")
        print("="*60)
        print("Check logs in logs/google_trends_ingest_*.log for details")
        sys.exit(1)
        
except Exception as e:
    print(f"\n[ERROR] Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
