"""
Data Quality Validation Script

This script performs comprehensive data quality checks:
- Checks for nulls in key columns (date, location, disease)
- Validates incremental loads do not duplicate records
- Validates date ranges match CDC/HHS reported ranges
- Outputs logs and summaries for any anomalies
"""

import os
import sys
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from collections import defaultdict

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(f"logs/data_quality_{datetime.now().strftime('%Y%m%d')}.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class DataQualityValidator:
    """Comprehensive data quality validation for influenza surveillance data."""
    
    def __init__(self, db_url: Optional[str] = None):
        """
        Initialize validator.
        
        Args:
            db_url: Database connection string (optional, uses env var if not provided)
        """
        self.db_url = db_url or os.getenv(
            'POSTGRES_URL',
            os.getenv('DATABASE_CONNECTION_STRING',
                     'postgresql://user:password@localhost:5432/influenza_db')
        )
        self.engine = create_engine(self.db_url)
        self.anomalies = []
        self.summary = {
            'total_checks': 0,
            'passed': 0,
            'failed': 0,
            'warnings': 0
        }
    
    def check_null_values(self, table_name: str, schema: str = 'facts',
                         key_columns: List[str] = None) -> Dict:
        """
        Check for null values in key columns.
        
        Args:
            table_name: Name of table to check
            schema: Schema name
            key_columns: List of key columns to check (default: date, location, disease)
            
        Returns:
            Dictionary with check results
        """
        if key_columns is None:
            key_columns = ['date_id', 'location_id', 'disease_id']
        
        self.summary['total_checks'] += 1
        check_name = f"Null Check: {schema}.{table_name}"
        
        try:
            full_table = f"{schema}.{table_name}"
            
            # Build query to check for nulls
            null_conditions = " OR ".join([f"{col} IS NULL" for col in key_columns])
            query = f"""
                SELECT 
                    COUNT(*) as total_rows,
                    SUM(CASE WHEN {null_conditions} THEN 1 ELSE 0 END) as null_rows
                FROM {full_table}
            """
            
            with self.engine.connect() as conn:
                result = conn.execute(text(query))
                row = result.fetchone()
                total_rows = row[0] if row else 0
                null_rows = row[1] if row else 0
            
            if null_rows > 0:
                self.summary['failed'] += 1
                anomaly = {
                    'check': check_name,
                    'severity': 'ERROR',
                    'message': f"Found {null_rows} rows with null values in key columns",
                    'details': {
                        'total_rows': total_rows,
                        'null_rows': null_rows,
                        'null_percentage': (null_rows / total_rows * 100) if total_rows > 0 else 0,
                        'key_columns': key_columns
                    }
                }
                self.anomalies.append(anomaly)
                logger.error(f"{check_name}: FAILED - {anomaly['message']}")
                return {'status': 'FAILED', 'null_rows': null_rows, 'total_rows': total_rows}
            else:
                self.summary['passed'] += 1
                logger.info(f"{check_name}: PASSED - No null values found")
                return {'status': 'PASSED', 'null_rows': 0, 'total_rows': total_rows}
                
        except Exception as e:
            self.summary['failed'] += 1
            logger.error(f"{check_name}: ERROR - {str(e)}", exc_info=True)
            return {'status': 'ERROR', 'error': str(e)}
    
    def check_duplicates(self, table_name: str, schema: str = 'facts',
                        unique_columns: List[str] = None) -> Dict:
        """
        Check for duplicate records based on unique key columns.
        
        Args:
            table_name: Name of table to check
            schema: Schema name
            unique_columns: Columns that should be unique (default: date, location, disease, source)
            
        Returns:
            Dictionary with check results
        """
        if unique_columns is None:
            unique_columns = ['date_id', 'location_id', 'disease_id', 'source_id']
        
        self.summary['total_checks'] += 1
        check_name = f"Duplicate Check: {schema}.{table_name}"
        
        try:
            full_table = f"{schema}.{table_name}"
            
            # Build query to find duplicates
            group_by_cols = ", ".join(unique_columns)
            query = f"""
                SELECT 
                    {group_by_cols},
                    COUNT(*) as duplicate_count
                FROM {full_table}
                GROUP BY {group_by_cols}
                HAVING COUNT(*) > 1
                ORDER BY duplicate_count DESC
                LIMIT 100
            """
            
            with self.engine.connect() as conn:
                result = conn.execute(text(query))
                duplicates = result.fetchall()
            
            if duplicates:
                duplicate_count = len(duplicates)
                total_duplicates = sum(row[-1] - 1 for row in duplicates)  # -1 because one is valid
                
                self.summary['failed'] += 1
                anomaly = {
                    'check': check_name,
                    'severity': 'ERROR',
                    'message': f"Found {duplicate_count} duplicate key combinations",
                    'details': {
                        'duplicate_combinations': duplicate_count,
                        'total_duplicate_rows': total_duplicates,
                        'sample_duplicates': [
                            {col: val for col, val in zip(unique_columns + ['count'], row)}
                            for row in duplicates[:10]
                        ]
                    }
                }
                self.anomalies.append(anomaly)
                logger.error(f"{check_name}: FAILED - {anomaly['message']}")
                return {'status': 'FAILED', 'duplicate_count': duplicate_count}
            else:
                self.summary['passed'] += 1
                logger.info(f"{check_name}: PASSED - No duplicates found")
                return {'status': 'PASSED', 'duplicate_count': 0}
                
        except Exception as e:
            self.summary['failed'] += 1
            logger.error(f"{check_name}: ERROR - {str(e)}", exc_info=True)
            return {'status': 'ERROR', 'error': str(e)}
    
    def check_date_ranges(self, table_name: str, schema: str = 'facts',
                          source_table: str = None) -> Dict:
        """
        Validate date ranges match CDC/HHS reported ranges.
        
        Args:
            table_name: Fact table name
            schema: Schema name
            source_table: Staging table name to compare against
            
        Returns:
            Dictionary with check results
        """
        self.summary['total_checks'] += 1
        check_name = f"Date Range Check: {schema}.{table_name}"
        
        try:
            # Get date range from fact table
            fact_query = f"""
                SELECT 
                    MIN(d.full_date) as min_date,
                    MAX(d.full_date) as max_date,
                    COUNT(DISTINCT d.full_date) as distinct_dates
                FROM {schema}.{table_name} f
                JOIN dimensions.dim_date d ON f.date_id = d.date_id
            """
            
            with self.engine.connect() as conn:
                result = conn.execute(text(fact_query))
                fact_range = result.fetchone()
                fact_min = fact_range[0] if fact_range[0] else None
                fact_max = fact_range[1] if fact_range[1] else None
                fact_dates = fact_range[2] if fact_range[2] else 0
            
            # Get date range from staging if provided
            staging_min = None
            staging_max = None
            staging_dates = 0
            
            if source_table:
                staging_query = f"""
                    SELECT 
                        MIN(load_timestamp::DATE) as min_date,
                        MAX(load_timestamp::DATE) as max_date,
                        COUNT(DISTINCT load_timestamp::DATE) as distinct_dates
                    FROM staging.{source_table}
                """
                
                with self.engine.connect() as conn:
                    result = conn.execute(text(staging_query))
                    staging_range = result.fetchone()
                    staging_min = staging_range[0] if staging_range[0] else None
                    staging_max = staging_range[1] if staging_range[1] else None
                    staging_dates = staging_range[2] if staging_range[2] else 0
            
            # Check for reasonable date ranges
            today = datetime.now().date()
            issues = []
            
            # Check if dates are in the future
            if fact_max and fact_max > today:
                issues.append(f"Max date ({fact_max}) is in the future")
            
            # Check if dates are too old (more than 5 years)
            if fact_min and fact_min < today - timedelta(days=5*365):
                issues.append(f"Min date ({fact_min}) is more than 5 years old")
            
            # Compare with staging if available
            if source_table and staging_min and staging_max:
                if fact_min != staging_min:
                    issues.append(f"Fact min date ({fact_min}) doesn't match staging ({staging_min})")
                if fact_max != staging_max:
                    issues.append(f"Fact max date ({fact_max}) doesn't match staging ({staging_max})")
            
            if issues:
                self.summary['warnings'] += 1
                anomaly = {
                    'check': check_name,
                    'severity': 'WARNING',
                    'message': f"Date range validation found {len(issues)} issues",
                    'details': {
                        'fact_date_range': {
                            'min': str(fact_min),
                            'max': str(fact_max),
                            'distinct_dates': fact_dates
                        },
                        'staging_date_range': {
                            'min': str(staging_min) if staging_min else None,
                            'max': str(staging_max) if staging_max else None,
                            'distinct_dates': staging_dates
                        } if source_table else None,
                        'issues': issues
                    }
                }
                self.anomalies.append(anomaly)
                logger.warning(f"{check_name}: WARNING - {anomaly['message']}")
                return {'status': 'WARNING', 'issues': issues}
            else:
                self.summary['passed'] += 1
                logger.info(f"{check_name}: PASSED - Date ranges are valid")
                return {
                    'status': 'PASSED',
                    'date_range': {'min': str(fact_min), 'max': str(fact_max)}
                }
                
        except Exception as e:
            self.summary['failed'] += 1
            logger.error(f"{check_name}: ERROR - {str(e)}", exc_info=True)
            return {'status': 'ERROR', 'error': str(e)}
    
    def check_incremental_load_integrity(self, table_name: str, schema: str = 'facts',
                                        lookback_days: int = 7) -> Dict:
        """
        Check that incremental loads do not create duplicates.
        
        Args:
            table_name: Fact table name
            schema: Schema name
            lookback_days: Number of days to check for incremental load issues
            
        Returns:
            Dictionary with check results
        """
        self.summary['total_checks'] += 1
        check_name = f"Incremental Load Integrity: {schema}.{table_name}"
        
        try:
            # Check for records with same key but different updated_timestamp
            # This indicates potential duplicate loads
            query = f"""
                WITH recent_updates AS (
                    SELECT 
                        date_id,
                        location_id,
                        disease_id,
                        source_id,
                        COUNT(*) as update_count,
                        MIN(updated_timestamp) as first_update,
                        MAX(updated_timestamp) as last_update
                    FROM {schema}.{table_name}
                    WHERE updated_timestamp >= CURRENT_DATE - INTERVAL '{lookback_days} days'
                    GROUP BY date_id, location_id, disease_id, source_id
                    HAVING COUNT(*) > 1
                )
                SELECT COUNT(*) as problematic_records
                FROM recent_updates
            """
            
            with self.engine.connect() as conn:
                result = conn.execute(text(query))
                problematic_count = result.scalar() or 0
            
            if problematic_count > 0:
                # Get details
                detail_query = f"""
                    SELECT 
                        date_id,
                        location_id,
                        disease_id,
                        source_id,
                        COUNT(*) as update_count,
                        MIN(updated_timestamp) as first_update,
                        MAX(updated_timestamp) as last_update
                    FROM {schema}.{table_name}
                    WHERE updated_timestamp >= CURRENT_DATE - INTERVAL '{lookback_days} days'
                    GROUP BY date_id, location_id, disease_id, source_id
                    HAVING COUNT(*) > 1
                    LIMIT 10
                """
                
                with self.engine.connect() as conn:
                    result = conn.execute(text(detail_query))
                    details = result.fetchall()
                
                self.summary['warnings'] += 1
                anomaly = {
                    'check': check_name,
                    'severity': 'WARNING',
                    'message': f"Found {problematic_count} key combinations with multiple updates",
                    'details': {
                        'problematic_records': problematic_count,
                        'lookback_days': lookback_days,
                        'sample_issues': [
                            {
                                'date_id': row[0],
                                'location_id': row[1],
                                'disease_id': row[2],
                                'source_id': row[3],
                                'update_count': row[4],
                                'first_update': str(row[5]),
                                'last_update': str(row[6])
                            }
                            for row in details
                        ]
                    }
                }
                self.anomalies.append(anomaly)
                logger.warning(f"{check_name}: WARNING - {anomaly['message']}")
                return {'status': 'WARNING', 'problematic_count': problematic_count}
            else:
                self.summary['passed'] += 1
                logger.info(f"{check_name}: PASSED - No incremental load issues found")
                return {'status': 'PASSED', 'problematic_count': 0}
                
        except Exception as e:
            self.summary['failed'] += 1
            logger.error(f"{check_name}: ERROR - {str(e)}", exc_info=True)
            return {'status': 'ERROR', 'error': str(e)}
    
    def check_data_freshness(self, table_name: str, schema: str = 'facts',
                           expected_delay_hours: int = 48) -> Dict:
        """
        Check that data is fresh (recently updated).
        
        Args:
            table_name: Fact table name
            schema: Schema name
            expected_delay_hours: Expected maximum delay in hours
            
        Returns:
            Dictionary with check results
        """
        self.summary['total_checks'] += 1
        check_name = f"Data Freshness: {schema}.{table_name}"
        
        try:
            query = f"""
                SELECT 
                    MAX(updated_timestamp) as last_update,
                    MAX(d.full_date) as latest_data_date
                FROM {schema}.{table_name} f
                JOIN dimensions.dim_date d ON f.date_id = d.date_id
            """
            
            with self.engine.connect() as conn:
                result = conn.execute(text(query))
                row = result.fetchone()
                last_update = row[0] if row[0] else None
                latest_data_date = row[1] if row[1] else None
            
            if not last_update:
                self.summary['failed'] += 1
                logger.error(f"{check_name}: FAILED - No data found")
                return {'status': 'FAILED', 'reason': 'No data'}
            
            # Check if data is stale
            hours_since_update = (datetime.now() - last_update).total_seconds() / 3600
            
            if hours_since_update > expected_delay_hours:
                self.summary['warnings'] += 1
                anomaly = {
                    'check': check_name,
                    'severity': 'WARNING',
                    'message': f"Data is stale - last update was {hours_since_update:.1f} hours ago",
                    'details': {
                        'last_update': str(last_update),
                        'hours_since_update': hours_since_update,
                        'expected_max_delay': expected_delay_hours,
                        'latest_data_date': str(latest_data_date)
                    }
                }
                self.anomalies.append(anomaly)
                logger.warning(f"{check_name}: WARNING - {anomaly['message']}")
                return {'status': 'WARNING', 'hours_since_update': hours_since_update}
            else:
                self.summary['passed'] += 1
                logger.info(f"{check_name}: PASSED - Data is fresh")
                return {'status': 'PASSED', 'hours_since_update': hours_since_update}
                
        except Exception as e:
            self.summary['failed'] += 1
            logger.error(f"{check_name}: ERROR - {str(e)}", exc_info=True)
            return {'status': 'ERROR', 'error': str(e)}
    
    def run_all_checks(self) -> Dict:
        """
        Run all data quality checks.
        
        Returns:
            Dictionary with summary and anomalies
        """
        logger.info("=" * 60)
        logger.info("Starting comprehensive data quality validation")
        logger.info("=" * 60)
        
        # Check fact_flu_cases_weekly
        logger.info("\n--- Checking fact_flu_cases_weekly ---")
        self.check_null_values('fact_flu_cases_weekly', 'facts')
        self.check_duplicates('fact_flu_cases_weekly', 'facts')
        self.check_date_ranges('fact_flu_cases_weekly', 'facts', 'fluview_raw')
        self.check_incremental_load_integrity('fact_flu_cases_weekly', 'facts')
        self.check_data_freshness('fact_flu_cases_weekly', 'facts')
        
        # Check fact_flu_hospitalizations_daily
        logger.info("\n--- Checking fact_flu_hospitalizations_daily ---")
        self.check_null_values('fact_flu_hospitalizations_daily', 'facts')
        self.check_duplicates('fact_flu_hospitalizations_daily', 'facts')
        self.check_date_ranges('fact_flu_hospitalizations_daily', 'facts', 'hhs_hospital_utilization_raw')
        self.check_incremental_load_integrity('fact_flu_hospitalizations_daily', 'facts')
        self.check_data_freshness('fact_flu_hospitalizations_daily', 'facts')
        
        # Print summary
        logger.info("\n" + "=" * 60)
        logger.info("Data Quality Validation Summary")
        logger.info("=" * 60)
        logger.info(f"Total Checks: {self.summary['total_checks']}")
        logger.info(f"Passed: {self.summary['passed']}")
        logger.info(f"Failed: {self.summary['failed']}")
        logger.info(f"Warnings: {self.summary['warnings']}")
        logger.info("=" * 60)
        
        if self.anomalies:
            logger.info(f"\nFound {len(self.anomalies)} anomalies:")
            for i, anomaly in enumerate(self.anomalies, 1):
                logger.info(f"\n{i}. {anomaly['check']} - {anomaly['severity']}")
                logger.info(f"   {anomaly['message']}")
        
        return {
            'summary': self.summary,
            'anomalies': self.anomalies
        }
    
    def print_summary_report(self):
        """Print a formatted summary report."""
        print("\n" + "=" * 80)
        print("DATA QUALITY VALIDATION REPORT")
        print("=" * 80)
        print(f"\nSummary:")
        print(f"  Total Checks: {self.summary['total_checks']}")
        print(f"  Passed: {self.summary['passed']} ✓")
        print(f"  Failed: {self.summary['failed']} ✗")
        print(f"  Warnings: {self.summary['warnings']} ⚠")
        
        if self.anomalies:
            print(f"\nAnomalies Found: {len(self.anomalies)}")
            print("\n" + "-" * 80)
            for i, anomaly in enumerate(self.anomalies, 1):
                print(f"\n{i}. {anomaly['check']}")
                print(f"   Severity: {anomaly['severity']}")
                print(f"   Message: {anomaly['message']}")
                if 'details' in anomaly:
                    print(f"   Details: {anomaly['details']}")
        else:
            print("\n✓ No anomalies found - all checks passed!")
        
        print("\n" + "=" * 80)


def main():
    """Main entry point for standalone execution."""
    validator = DataQualityValidator()
    results = validator.run_all_checks()
    validator.print_summary_report()
    
    # Exit with error code if there are failures
    if results['summary']['failed'] > 0:
        sys.exit(1)
    elif results['summary']['warnings'] > 0:
        sys.exit(0)  # Warnings don't fail the script
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
