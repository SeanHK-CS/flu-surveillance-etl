"""
Example usage of the CDC FluView ingestion script.

This demonstrates how to use the FluViewIngester class programmatically.
"""

import os
from ingest_cdc_fluview import FluViewIngester

# Example 1: Basic usage with environment variables
# Set these environment variables:
#   WAREHOUSE=postgres
#   POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
#   STAGING_SCHEMA=staging
#   STAGING_TABLE=fluview_raw

if __name__ == "__main__":
    # Initialize ingester
    ingester = FluViewIngester()
    
    # Run ingestion
    success = ingester.run_ingestion()
    
    if success:
        print("Ingestion completed successfully!")
    else:
        print("Ingestion failed. Check logs for details.")
        exit(1)
