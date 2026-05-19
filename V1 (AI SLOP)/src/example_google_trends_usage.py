"""
Example usage of the Google Trends ingestion script.

This demonstrates how to use the GoogleTrendsIngester class programmatically.
"""

import os
from datetime import datetime, timedelta
from ingest_google_trends import GoogleTrendsIngester

# Example 1: Basic usage with environment variables
# Set these environment variables:
#   WAREHOUSE=postgres
#   POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
#   STAGING_SCHEMA=staging
#   GOOGLE_TRENDS_STAGING_TABLE=google_trends_raw
#   GOOGLE_TRENDS_TERMS=flu,influenza,flu symptoms

if __name__ == "__main__":
    # Initialize ingester
    ingester = GoogleTrendsIngester()
    
    # Run ingestion for last 30 days (default)
    success = ingester.run_ingestion()
    
    # Or specify custom date range
    # end_date = datetime.now()
    # start_date = end_date - timedelta(days=90)
    # success = ingester.run_ingestion(start_date=start_date, end_date=end_date)
    
    # Or process specific states only
    # states = ['US-CA', 'US-NY', 'US-TX']
    # success = ingester.run_ingestion(states=states)
    
    if success:
        print("Google Trends ingestion completed successfully!")
    else:
        print("Ingestion completed with some errors. Check logs for details.")
        exit(1)
