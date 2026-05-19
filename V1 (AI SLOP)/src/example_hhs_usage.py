"""
Example usage of the HHS Hospital Utilization ingestion script.

This demonstrates how to use the HHSHospitalUtilizationIngester class programmatically.
"""

import os
from ingest_hhs_hospital_utilization import HHSHospitalUtilizationIngester

# Example 1: Basic usage with environment variables
# Set these environment variables:
#   WAREHOUSE=postgres
#   POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
#   STAGING_SCHEMA=staging
#   HHS_STAGING_TABLE=hhs_hospital_utilization_raw
#   HHS_LOOKBACK_DAYS=7

if __name__ == "__main__":
    # Initialize ingester
    ingester = HHSHospitalUtilizationIngester()
    
    # Run ingestion with default lookback (7 days)
    success = ingester.run_ingestion()
    
    # Or specify custom lookback period
    # success = ingester.run_ingestion(lookback_days=14)
    
    if success:
        print("HHS Hospital Utilization ingestion completed successfully!")
    else:
        print("Ingestion completed with some errors. Check logs for details.")
        exit(1)
