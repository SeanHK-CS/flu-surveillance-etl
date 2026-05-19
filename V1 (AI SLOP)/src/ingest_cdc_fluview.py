"""
CDC FluView Weekly Influenza Data Ingestion Script

This script:
- Pulls CDC FluView weekly influenza data via their public API
- Saves raw JSON/CSV files to a local 'raw/' folder partitioned by date
- Loads the data into a staging table in Postgres or BigQuery warehouse
- Handles schema changes gracefully
- Logs ingestion success or failure
- Is idempotent if run multiple times
"""

import os
import json
import csv
import logging
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
import hashlib

import requests
import pandas as pd
from sqlalchemy import create_engine, text, inspect
from sqlalchemy.exc import SQLAlchemyError

# Try to import BigQuery (optional dependency)
try:
    from google.cloud import bigquery
    from google.cloud.exceptions import GoogleCloudError
    BIGQUERY_AVAILABLE = True
except ImportError:
    BIGQUERY_AVAILABLE = False

# Configuration
RAW_DIR = os.getenv("RAW_DATA_DIR", "raw")
LOG_DIR = os.getenv("LOG_DIR", "logs")
STAGING_SCHEMA = os.getenv("STAGING_SCHEMA", "staging")
STAGING_TABLE = os.getenv("STAGING_TABLE", "fluview_raw")

# CDC FluView API via Delphi Epidata API
API_ENDPOINT = "https://api.delphi.cmu.edu/epidata/fluview/"
API_PARAMS = {
    "regions": os.getenv("FLUVIEW_REGIONS", "nat"),  # nat, hhs, census, state
    "epiweeks": os.getenv("FLUVIEW_EPIWEEKS", "latest"),  # latest or range like "202440-202452"
}

# Warehouse configuration
WAREHOUSE = os.getenv("WAREHOUSE", "postgres").lower()  # "postgres" or "bigquery"

# Postgres connection
POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    os.getenv("DATABASE_CONNECTION_STRING", "postgresql://user:password@localhost:5432/influenza_db")
)

# BigQuery configuration
BQ_PROJECT = os.getenv("BQ_PROJECT", "")
BQ_DATASET = os.getenv("BQ_DATASET", "influenza_staging")
BQ_LOCATION = os.getenv("BQ_LOCATION", "US")

# Setup logging
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, f"fluview_ingest_{datetime.now().strftime('%Y%m%d')}.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class FluViewIngester:
    """Main class for ingesting CDC FluView data."""
    
    def __init__(self):
        """Initialize the ingester."""
        self.raw_dir = Path(RAW_DIR)
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Influenza-Surveillance-ETL/1.0"
        })
    
    def fetch_fluview_data(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """
        Fetch data from the CDC FluView API (via Delphi Epidata).
        
        Args:
            params: API parameters
            
        Returns:
            API response as dictionary
            
        Raises:
            requests.RequestException: If API request fails
        """
        try:
            logger.info(f"Fetching FluView data from {API_ENDPOINT} with params: {params}")
            response = self.session.get(API_ENDPOINT, params=params, timeout=60)
            response.raise_for_status()
            data = response.json()
            
            if data.get("result") != 1:
                error_msg = data.get("message", "Unknown API error")
                raise ValueError(f"API returned error: {error_msg}")
            
            logger.info(f"Successfully fetched {len(data.get('epidata', []))} records")
            return data
            
        except requests.RequestException as e:
            logger.error(f"Failed to fetch data from API: {e}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse API response as JSON: {e}")
            raise
    
    def save_raw_files(self, data: Dict[str, Any], week_identifier: str) -> Tuple[str, str]:
        """
        Save raw JSON and CSV files partitioned by date.
        
        Args:
            data: Raw API response data
            week_identifier: Week identifier (epiweek or date)
            
        Returns:
            Tuple of (json_path, csv_path)
        """
        # Create date-partitioned directory structure: raw/YYYY/MM/DD/
        today = datetime.now()
        date_partition = self.raw_dir / today.strftime("%Y") / today.strftime("%m") / today.strftime("%d")
        date_partition.mkdir(parents=True, exist_ok=True)
        
        # Generate file paths with timestamp and week identifier
        timestamp = today.strftime("%Y%m%d_%H%M%S")
        base_name = f"fluview_{week_identifier}_{timestamp}"
        
        json_path = date_partition / f"{base_name}.json"
        csv_path = date_partition / f"{base_name}.csv"
        
        # Save JSON
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, default=str)
        logger.info(f"Saved raw JSON to {json_path}")
        
        # Save CSV
        epidata = data.get("epidata", [])
        if epidata:
            df = pd.DataFrame(epidata)
            df.to_csv(csv_path, index=False)
            logger.info(f"Saved raw CSV to {csv_path} ({len(df)} rows)")
        else:
            logger.warning("No epidata found in response, skipping CSV save")
        
        return str(json_path), str(csv_path)
    
    def prepare_dataframe(self, data: Dict[str, Any]) -> pd.DataFrame:
        """
        Prepare DataFrame from API response with data type conversions.
        
        Args:
            data: API response data
            
        Returns:
            Prepared DataFrame
        """
        epidata = data.get("epidata", [])
        if not epidata:
            logger.warning("No epidata found in response")
            return pd.DataFrame()
        
        df = pd.DataFrame(epidata)
        
        # Add metadata columns
        df['ingestion_timestamp'] = datetime.now()
        df['data_source'] = 'cdc_fluview_api'
        df['api_result'] = data.get("result", 0)
        
        # Convert date columns if present
        date_columns = ['week_ending', 'release_date', 'issue_date']
        for col in date_columns:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], errors='coerce')
        
        # Ensure epiweek is integer
        if 'epiweek' in df.columns:
            df['epiweek'] = pd.to_numeric(df['epiweek'], errors='coerce').astype('Int64')
        
        # Normalize column names (lowercase, replace spaces/special chars)
        df.columns = df.columns.str.lower().str.replace(' ', '_').str.replace('-', '_')
        
        logger.info(f"Prepared DataFrame with {len(df)} rows and {len(df.columns)} columns")
        return df
    
    def get_schema_mapping(self, df: pd.DataFrame) -> Dict[str, str]:
        """
        Infer SQL schema from DataFrame.
        
        Args:
            df: DataFrame to infer schema from
            
        Returns:
            Dictionary mapping column names to SQL types
        """
        type_map = {}
        for col, dtype in df.dtypes.items():
            if pd.api.types.is_integer_dtype(dtype):
                type_map[col] = "BIGINT"
            elif pd.api.types.is_float_dtype(dtype):
                type_map[col] = "DOUBLE PRECISION"
            elif pd.api.types.is_bool_dtype(dtype):
                type_map[col] = "BOOLEAN"
            elif pd.api.types.is_datetime64_any_dtype(dtype):
                type_map[col] = "TIMESTAMP"
            else:
                # Default to TEXT for strings and unknown types
                type_map[col] = "TEXT"
        return type_map
    
    def ensure_postgres_table(self, engine, table_name: str, df: pd.DataFrame) -> None:
        """
        Create or alter Postgres table to match DataFrame schema.
        Handles schema changes gracefully by adding new columns.
        
        Args:
            engine: SQLAlchemy engine
            table_name: Full table name (schema.table)
            df: DataFrame to match schema
        """
        schema_map = self.get_schema_mapping(df)
        
        with engine.begin() as conn:
            # Check if table exists
            schema, table = table_name.split('.') if '.' in table_name else ('public', table_name)
            
            check_sql = text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = :schema 
                    AND table_name = :table
                )
            """)
            exists = conn.execute(check_sql, {"schema": schema, "table": table}).scalar()
            
            if not exists:
                # Create table
                cols = ", ".join([f'"{col}" {dtype}' for col, dtype in schema_map.items()])
                create_sql = text(f'CREATE TABLE {table_name} ({cols});')
                conn.execute(create_sql)
                logger.info(f"Created table {table_name} with {len(schema_map)} columns")
            else:
                # Add missing columns
                existing_cols_sql = text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_schema = :schema 
                    AND table_name = :table
                """)
                existing_cols = {
                    row[0] for row in conn.execute(existing_cols_sql, {"schema": schema, "table": table})
                }
                
                for col, dtype in schema_map.items():
                    if col not in existing_cols:
                        alter_sql = text(f'ALTER TABLE {table_name} ADD COLUMN "{col}" {dtype};')
                        try:
                            conn.execute(alter_sql)
                            logger.info(f"Added column {col} ({dtype}) to {table_name}")
                        except SQLAlchemyError as e:
                            logger.warning(f"Could not add column {col}: {e}")
    
    def load_to_postgres(self, df: pd.DataFrame, table_name: str, engine) -> None:
        """
        Load DataFrame to Postgres with idempotency.
        
        Args:
            df: DataFrame to load
            table_name: Full table name (schema.table)
            engine: SQLAlchemy engine
        """
        if df.empty:
            logger.warning("DataFrame is empty, nothing to load")
            return
        
        # Ensure table exists with correct schema
        self.ensure_postgres_table(engine, table_name, df)
        
        # Idempotency: Delete existing records for the same epiweek(s) before inserting
        if 'epiweek' in df.columns:
            epiweeks = df['epiweek'].dropna().unique().tolist()
            if epiweeks:
                with engine.begin() as conn:
                    delete_sql = text(f'DELETE FROM {table_name} WHERE epiweek IN :epiweeks')
                    # Convert to tuple for IN clause
                    conn.execute(delete_sql, {"epiweeks": tuple(epiweeks)})
                    logger.info(f"Deleted existing records for epiweeks: {epiweeks}")
        else:
            logger.warning("No epiweek column found; cannot enforce idempotency by week")
        
        # Insert new data
        try:
            df.to_sql(
                table_name.split('.')[-1],  # Table name without schema
                engine,
                schema=table_name.split('.')[0] if '.' in table_name else None,
                if_exists='append',
                index=False,
                method='multi'
            )
            logger.info(f"Successfully loaded {len(df)} rows into {table_name}")
        except SQLAlchemyError as e:
            logger.error(f"Failed to load data to Postgres: {e}")
            raise
    
    def load_to_bigquery(self, df: pd.DataFrame, table_name: str) -> None:
        """
        Load DataFrame to BigQuery with schema update support.
        
        Args:
            df: DataFrame to load
            table_name: Table name (without project.dataset prefix)
        """
        if not BIGQUERY_AVAILABLE:
            raise ImportError("google-cloud-bigquery is not installed. Install it with: pip install google-cloud-bigquery")
        
        if df.empty:
            logger.warning("DataFrame is empty, nothing to load")
            return
        
        if not BQ_PROJECT:
            raise ValueError("BQ_PROJECT environment variable must be set for BigQuery")
        
        client = bigquery.Client(project=BQ_PROJECT, location=BQ_LOCATION)
        table_ref = f"{BQ_PROJECT}.{BQ_DATASET}.{table_name}"
        
        # Configure load job with schema update options
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # Idempotent: replace partition
            schema_update_options=[
                bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION
            ],
            autodetect=True,  # Auto-detect schema
        )
        
        # Add partitioning if week_ending column exists
        if 'week_ending' in df.columns:
            job_config.time_partitioning = bigquery.TimePartitioning(
                field="week_ending",
                type_=bigquery.TimePartitioningType.DAY
            )
        
        try:
            load_job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
            load_job.result()  # Wait for job to complete
            
            table = client.get_table(table_ref)
            logger.info(
                f"Successfully loaded {load_job.output_rows} rows into BigQuery {table_ref} "
                f"(table now has {table.num_rows} total rows)"
            )
        except GoogleCloudError as e:
            logger.error(f"Failed to load data to BigQuery: {e}")
            raise
    
    def run_ingestion(self) -> bool:
        """
        Run the complete ingestion process.
        
        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info("=" * 60)
            logger.info("Starting CDC FluView data ingestion")
            logger.info(f"Warehouse: {WAREHOUSE}")
            logger.info(f"Raw data directory: {self.raw_dir}")
            logger.info("=" * 60)
            
            # Step 1: Fetch data from API
            api_data = self.fetch_fluview_data(API_PARAMS)
            
            epidata = api_data.get("epidata", [])
            if not epidata:
                logger.warning("No data returned from API; nothing to process")
                return True  # Not an error, just no data
            
            # Step 2: Determine week identifier for file naming
            week_id = str(epidata[0].get("epiweek", datetime.now().strftime("%Y%W")))
            
            # Step 3: Save raw files
            json_path, csv_path = self.save_raw_files(api_data, week_id)
            
            # Step 4: Prepare DataFrame
            df = self.prepare_dataframe(api_data)
            
            if df.empty:
                logger.warning("DataFrame is empty after preparation")
                return True
            
            # Step 5: Load to warehouse
            full_table_name = f"{STAGING_SCHEMA}.{STAGING_TABLE}"
            
            if WAREHOUSE == "postgres":
                engine = create_engine(POSTGRES_URL)
                self.load_to_postgres(df, full_table_name, engine)
            elif WAREHOUSE == "bigquery":
                self.load_to_bigquery(df, STAGING_TABLE)
            else:
                raise ValueError(f"Unknown warehouse type: {WAREHOUSE}. Must be 'postgres' or 'bigquery'")
            
            logger.info("=" * 60)
            logger.info("CDC FluView data ingestion completed successfully")
            logger.info("=" * 60)
            return True
            
        except Exception as e:
            logger.error("=" * 60)
            logger.error(f"CDC FluView data ingestion FAILED: {e}", exc_info=True)
            logger.error("=" * 60)
            return False


def main():
    """Main entry point for the script."""
    ingester = FluViewIngester()
    success = ingester.run_ingestion()
    
    if not success:
        exit(1)


if __name__ == "__main__":
    main()
