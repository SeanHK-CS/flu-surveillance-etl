"""
Run Google Trends ingestion for Illinois only.
"""

import os
import sys
from datetime import datetime, timedelta

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from ingest_google_trends import GoogleTrendsIngester

if __name__ == "__main__":
    print("=" * 60)
    print("Google Trends Ingestion - Illinois Only")
    print("=" * 60)
    
    # Initialize ingester
    ingester = GoogleTrendsIngester()
    
    # Run ingestion for Illinois only (last 30 days by default)
    # Illinois state code: US-IL
    states = ['US-IL']
    
    print(f"\nProcessing state: Illinois (US-IL)")
    print("Date range: Last 30 days (default)")
    print("\nStarting ingestion...\n")
    
    success = ingester.run_ingestion(states=states)
    
    if success:
        print("\n" + "=" * 60)
        print("[SUCCESS] Illinois ingestion completed successfully!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Check staging: SELECT COUNT(*) FROM staging.google_trends_raw WHERE state_abbreviation = 'IL';")
        print("2. Transform to facts: SELECT * FROM transform.load_google_trends_to_facts(NULL, NULL, false);")
        print("3. Calculate metrics: SELECT * FROM transform.update_search_interest_rolling_averages(NULL, NULL);")
    else:
        print("\n" + "=" * 60)
        print("[ERROR] Ingestion completed with errors. Check logs for details.")
        print("=" * 60)
        sys.exit(1)
