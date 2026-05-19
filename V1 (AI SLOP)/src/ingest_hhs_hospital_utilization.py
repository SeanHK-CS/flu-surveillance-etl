"""
HHS Hospital Utilization Data Ingestion Script

This script:
- Downloads HHS hospital utilization CSV data (flu-related admissions, ICU usage, bed capacity)
- Stores raw files in 'raw/' folder with date partitions
- Loads data into a staging table
- Normalizes location codes and dates to match CDC data
- Handles missing or late-arriving data
- Logs ingestion success/failure
"""

import os
import json
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
STAGING_TABLE = os.getenv("HHS_STAGING_TABLE", "hhs_hospital_utilization_raw")

# HHS Data Source - HealthData.gov Hospital Utilization dataset
# This is the Socrata API endpoint for HHS hospital utilization data
HHS_DATA_ENDPOINT = os.getenv(
    "HHS_DATA_ENDPOINT",
    "https://healthdata.gov/resource/g62h-syeh.csv"  # Hospital capacity and utilization
)

# Alternative endpoint for flu-specific admissions (if available)
HHS_FLU_ADMISSIONS_ENDPOINT = os.getenv(
    "HHS_FLU_ADMISSIONS_ENDPOINT",
    "https://healthdata.gov/resource/g62h-syeh.csv?$where=collection_week>='2020-01-01'"
)

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

# Days to look back for late-arriving data
LOOKBACK_DAYS = int(os.getenv("HHS_LOOKBACK_DAYS", "7"))

# Setup logging
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, f"hhs_ingest_{datetime.now().strftime('%Y%m%d')}.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# State code to FIPS code mapping (for normalization)
STATE_TO_FIPS = {
    "AL": "01", "AK": "02", "AZ": "04", "AR": "05", "CA": "06",
    "CO": "08", "CT": "09", "DE": "10", "FL": "12", "GA": "13",
    "HI": "15", "ID": "16", "IL": "17", "IN": "18", "IA": "19",
    "KS": "20", "KY": "21", "LA": "22", "ME": "23", "MD": "24",
    "MA": "25", "MI": "26", "MN": "27", "MS": "28", "MO": "29",
    "MT": "30", "NE": "31", "NV": "32", "NH": "33", "NJ": "34",
    "NM": "35", "NY": "36", "NC": "37", "ND": "38", "OH": "39",
    "OK": "40", "OR": "41", "PA": "42", "RI": "43", "SC": "45",
    "SD": "46", "TN": "47", "TX": "48", "UT": "49", "VT": "50",
    "VA": "51", "WA": "53", "WV": "54", "WI": "55", "WY": "56",
    "DC": "11", "PR": "72", "VI": "78", "AS": "60", "GU": "66", "MP": "69"
}

# Reverse mapping: FIPS to state code
FIPS_TO_STATE = {v: k for k, v in STATE_TO_FIPS.items()}


class HHSHospitalUtilizationIngester:
    """Main class for ingesting HHS hospital utilization data."""
    
    def __init__(self):
        """Initialize the ingester."""
        self.raw_dir = Path(RAW_DIR)
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Influenza-Surveillance-ETL/1.0",
            "Accept": "text/csv"
        })
    
    def download_hhs_data(self, date: Optional[datetime] = None, 
                         endpoint: Optional[str] = None) -> Tuple[str, pd.DataFrame]:
        """
        Download HHS hospital utilization CSV data.
        
        Args:
            date: Optional date to filter data (for late arrivals)
            endpoint: Optional custom endpoint URL
            
        Returns:
            Tuple of (file_path, DataFrame)
            
        Raises:
            requests.RequestException: If download fails
        """
        endpoint = endpoint or HHS_DATA_ENDPOINT
        
        try:
            # Add date filter if provided
            if date:
                date_str = date.strftime("%Y-%m-%d")
                # Socrata API date filtering
                endpoint = f"{HHS_DATA_ENDPOINT}?$where=collection_week>='{date_str}'"
            
            logger.info(f"Downloading HHS data from {endpoint}")
            response = self.session.get(endpoint, timeout=120)
            response.raise_for_status()
            
            # Read CSV directly into DataFrame
            df = pd.read_csv(
                endpoint,
                dtype=str,  # Read all as strings first, then convert
                low_memory=False
            )
            
            logger.info(f"Successfully downloaded {len(df)} records from HHS")
            return endpoint, df
            
        except requests.RequestException as e:
            logger.error(f"Failed to download HHS data: {e}")
            raise
        except Exception as e:
            logger.error(f"Error processing HHS data: {e}")
            raise
    
    def save_raw_file(self, df: pd.DataFrame, date: datetime) -> str:
        """
        Save raw CSV file partitioned by date.
        
        Args:
            df: DataFrame to save
            date: Date for partitioning
            
        Returns:
            Path to saved file
        """
        # Create date-partitioned directory: raw/hhs/YYYY/MM/DD/
        date_partition = self.raw_dir / "hhs" / date.strftime("%Y") / date.strftime("%m") / date.strftime("%d")
        date_partition.mkdir(parents=True, exist_ok=True)
        
        # Generate file path with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"hhs_hospital_utilization_{date.strftime('%Y%m%d')}_{timestamp}.csv"
        file_path = date_partition / filename
        
        # Save CSV
        df.to_csv(file_path, index=False)
        logger.info(f"Saved raw CSV to {file_path} ({len(df)} rows)")
        
        # Also save metadata JSON
        metadata = {
            "source": "HHS HealthData.gov",
            "download_date": datetime.now().isoformat(),
            "data_date": date.isoformat(),
            "row_count": len(df),
            "columns": list(df.columns),
            "file_path": str(file_path)
        }
        metadata_path = file_path.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        return str(file_path)
    
    def normalize_location_codes(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Normalize location codes to match CDC data format.
        Converts state abbreviations to FIPS codes and standardizes location fields.
        
        Args:
            df: DataFrame with location data
            
        Returns:
            DataFrame with normalized location codes
        """
        df = df.copy()
        
        # Normalize state codes
        state_columns = ['state', 'state_abbreviation', 'state_code', 'state_name']
        state_col = None
        for col in state_columns:
            if col in df.columns:
                state_col = col
                break
        
        if state_col:
            # Convert to uppercase and strip whitespace
            df[state_col] = df[state_col].astype(str).str.strip().str.upper()
            
            # Add FIPS code column
            df['state_fips'] = df[state_col].map(STATE_TO_FIPS)
            
            # Handle missing mappings
            missing_fips = df[df['state_fips'].isna() & df[state_col].notna()]
            if not missing_fips.empty:
                logger.warning(f"Could not map {len(missing_fips)} rows to FIPS codes")
                logger.debug(f"Unmapped state values: {missing_fips[state_col].unique()}")
        
        # Normalize HHS region codes if present
        if 'hhs_region' in df.columns:
            df['hhs_region'] = pd.to_numeric(df['hhs_region'], errors='coerce')
        
        # Normalize facility identifiers
        facility_id_cols = ['fips_code', 'facility_id', 'cms_certification_number']
        for col in facility_id_cols:
            if col in df.columns:
                df[col] = df[col].astype(str).str.strip()
        
        return df
    
    def normalize_dates(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Normalize date columns to match CDC data format.
        Converts various date formats to standard datetime.
        
        Args:
            df: DataFrame with date columns
            
        Returns:
            DataFrame with normalized dates
        """
        df = df.copy()
        
        # Common date column names in HHS data
        date_columns = [
            'collection_week',
            'date',
            'week_ending',
            'report_date',
            'collection_date',
            'week_start'
        ]
        
        # Find and normalize date columns
        for col in date_columns:
            if col in df.columns:
                # Try multiple date formats
                df[col] = pd.to_datetime(df[col], errors='coerce', infer_datetime_format=True)
                
                # Add standardized date column for CDC matching
                if col == 'collection_week':
                    df['week_ending'] = df[col]
                    # Calculate epiweek if needed (CDC format)
                    df['epiweek'] = df[col].apply(self._date_to_epiweek)
        
        # Add ingestion timestamp
        df['ingestion_timestamp'] = datetime.now()
        
        return df
    
    def _date_to_epiweek(self, date: pd.Timestamp) -> Optional[int]:
        """
        Convert date to CDC epiweek format (YYYYWW).
        
        Args:
            date: Date to convert
            
        Returns:
            Epiweek as integer (YYYYWW) or None
        """
        if pd.isna(date):
            return None
        
        try:
            # Get ISO week
            year = date.year
            week = date.isocalendar()[1]
            
            # Handle year boundary cases
            if week == 1 and date.month == 12:
                year += 1
            elif week >= 52 and date.month == 1:
                year -= 1
            
            return int(f"{year}{week:02d}")
        except:
            return None
    
    def handle_missing_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Handle missing or late-arriving data.
        Forward fill where appropriate, mark missing data.
        
        Args:
            df: DataFrame with potential missing data
            
        Returns:
            DataFrame with handled missing data
        """
        df = df.copy()
        
        # Sort by location and date for forward fill
        sort_cols = []
        if 'state_fips' in df.columns:
            sort_cols.append('state_fips')
        if 'collection_week' in df.columns:
            sort_cols.append('collection_week')
        elif 'date' in df.columns:
            sort_cols.append('date')
        
        if sort_cols:
            df = df.sort_values(sort_cols)
        
        # Identify numeric columns for forward fill
        numeric_cols = df.select_dtypes(include=[pd.Int64Dtype(), pd.Float64Dtype(), 'int64', 'float64']).columns
        
        # Mark missing data
        df['has_missing_data'] = df[numeric_cols].isnull().any(axis=1)
        
        # For capacity metrics, forward fill within same location
        capacity_cols = [col for col in numeric_cols if any(x in col.lower() for x in ['bed', 'capacity', 'total'])]
        if capacity_cols and sort_cols:
            df[capacity_cols] = df.groupby(sort_cols[0])[capacity_cols].fillna(method='ffill')
        
        # Count missing values
        missing_count = df['has_missing_data'].sum()
        if missing_count > 0:
            logger.warning(f"Found {missing_count} rows with missing data")
        
        return df
    
    def prepare_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare DataFrame with all normalizations.
        
        Args:
            df: Raw DataFrame from HHS
            
        Returns:
            Prepared DataFrame
        """
        logger.info(f"Preparing DataFrame: {len(df)} rows, {len(df.columns)} columns")
        
        # Normalize column names
        df.columns = df.columns.str.lower().str.replace(' ', '_').str.replace('-', '_')
        
        # Normalize locations
        df = self.normalize_location_codes(df)
        
        # Normalize dates
        df = self.normalize_dates(df)
        
        # Handle missing data
        df = self.handle_missing_data(df)
        
        # Add metadata
        df['data_source'] = 'hhs_hospital_utilization'
        df['source_system'] = 'healthdata.gov'
        
        # Convert numeric columns
        numeric_columns = [
            'total_adult_patients_hospitalized_confirmed_and_suspected_covid',
            'total_adult_patients_hospitalized_confirmed_covid',
            'total_pediatric_patients_hospitalized_confirmed_and_suspected_covid',
            'total_pediatric_patients_hospitalized_confirmed_covid',
            'staffed_icu_adult_patients_confirmed_and_suspected_covid',
            'staffed_icu_adult_patients_confirmed_covid',
            'total_staffed_adult_icu_beds',
            'total_staffed_adult_icu_beds_occupied',
            'inpatient_beds',
            'inpatient_beds_occupied',
            'inpatient_beds_used',
            'all_adult_hospital_inpatient_beds',
            'all_adult_hospital_inpatient_bed_occupied',
            'all_pediatric_inpatient_beds',
            'all_pediatric_inpatient_beds_occupied',
            'all_adult_hospital_icu_beds',
            'all_adult_hospital_icu_beds_occupied',
            'hhs_region'
        ]
        
        for col in numeric_columns:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
        
        logger.info(f"Prepared DataFrame: {len(df)} rows, {len(df.columns)} columns")
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
                type_map[col] = "TEXT"
        return type_map
    
    def ensure_postgres_table(self, engine, table_name: str, df: pd.DataFrame) -> None:
        """
        Create or alter Postgres table to match DataFrame schema.
        
        Args:
            engine: SQLAlchemy engine
            table_name: Full table name (schema.table)
            df: DataFrame to match schema
        """
        schema_map = self.get_schema_mapping(df)
        
        with engine.begin() as conn:
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
                cols = ", ".join([f'"{col}" {dtype}' for col, dtype in schema_map.items()])
                create_sql = text(f'CREATE TABLE {table_name} ({cols});')
                conn.execute(create_sql)
                logger.info(f"Created table {table_name} with {len(schema_map)} columns")
            else:
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
        
        self.ensure_postgres_table(engine, table_name, df)
        
        # Idempotency: Delete existing records for same collection_week and location
        delete_cols = []
        if 'collection_week' in df.columns:
            delete_cols.append('collection_week')
        if 'state_fips' in df.columns:
            delete_cols.append('state_fips')
        elif 'state' in df.columns:
            delete_cols.append('state')
        
        if delete_cols:
            with engine.begin() as conn:
                for _, row in df[delete_cols].drop_duplicates().iterrows():
                    conditions = []
                    params = {}
                    for col in delete_cols:
                        val = row[col]
                        if pd.notna(val):
                            conditions.append(f'"{col}" = :{col}')
                            params[col] = val
                    
                    if conditions:
                        delete_sql = text(f'DELETE FROM {table_name} WHERE {" AND ".join(conditions)}')
                        conn.execute(delete_sql, params)
        
        # Insert new data
        try:
            df.to_sql(
                table_name.split('.')[-1],
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
            raise ImportError("google-cloud-bigquery is not installed")
        
        if df.empty:
            logger.warning("DataFrame is empty, nothing to load")
            return
        
        if not BQ_PROJECT:
            raise ValueError("BQ_PROJECT environment variable must be set")
        
        client = bigquery.Client(project=BQ_PROJECT, location=BQ_LOCATION)
        table_ref = f"{BQ_PROJECT}.{BQ_DATASET}.{table_name}"
        
        job_config = bigquery.LoadJobConfig(
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
            schema_update_options=[bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION],
            autodetect=True,
        )
        
        if 'collection_week' in df.columns:
            job_config.time_partitioning = bigquery.TimePartitioning(
                field="collection_week",
                type_=bigquery.TimePartitioningType.DAY
            )
        
        try:
            load_job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
            load_job.result()
            table = client.get_table(table_ref)
            logger.info(f"Successfully loaded {load_job.output_rows} rows into BigQuery {table_ref}")
        except GoogleCloudError as e:
            logger.error(f"Failed to load data to BigQuery: {e}")
            raise
    
    def run_ingestion(self, lookback_days: int = LOOKBACK_DAYS) -> bool:
        """
        Run the complete ingestion process with late-arriving data handling.
        
        Args:
            lookback_days: Number of days to look back for late-arriving data
            
        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info("=" * 60)
            logger.info("Starting HHS Hospital Utilization data ingestion")
            logger.info(f"Warehouse: {WAREHOUSE}")
            logger.info(f"Lookback days: {lookback_days}")
            logger.info("=" * 60)
            
            # Process current date and lookback period for late arrivals
            today = datetime.now()
            success_count = 0
            error_count = 0
            
            for days_back in range(lookback_days + 1):
                target_date = today - timedelta(days=days_back)
                
                try:
                    logger.info(f"Processing data for {target_date.strftime('%Y-%m-%d')}")
                    
                    # Download data
                    endpoint, df = self.download_hhs_data(date=target_date)
                    
                    if df.empty:
                        logger.info(f"No data available for {target_date.strftime('%Y-%m-%d')}")
                        continue
                    
                    # Save raw file
                    file_path = self.save_raw_file(df, target_date)
                    
                    # Prepare DataFrame
                    df_prepared = self.prepare_dataframe(df)
                    
                    if df_prepared.empty:
                        logger.warning(f"DataFrame is empty after preparation for {target_date}")
                        continue
                    
                    # Load to warehouse
                    full_table_name = f"{STAGING_SCHEMA}.{STAGING_TABLE}"
                    
                    if WAREHOUSE == "postgres":
                        engine = create_engine(POSTGRES_URL)
                        self.load_to_postgres(df_prepared, full_table_name, engine)
                    elif WAREHOUSE == "bigquery":
                        self.load_to_bigquery(df_prepared, STAGING_TABLE)
                    else:
                        raise ValueError(f"Unknown warehouse: {WAREHOUSE}")
                    
                    success_count += 1
                    logger.info(f"Successfully processed data for {target_date.strftime('%Y-%m-%d')}")
                    
                except Exception as e:
                    error_count += 1
                    logger.error(f"Error processing data for {target_date.strftime('%Y-%m-%d')}: {e}", exc_info=True)
                    # Continue processing other dates even if one fails
            
            logger.info("=" * 60)
            logger.info(f"HHS Hospital Utilization ingestion completed")
            logger.info(f"Successfully processed: {success_count} date(s)")
            logger.info(f"Errors: {error_count} date(s)")
            logger.info("=" * 60)
            
            return error_count == 0
            
        except Exception as e:
            logger.error("=" * 60)
            logger.error(f"HHS Hospital Utilization ingestion FAILED: {e}", exc_info=True)
            logger.error("=" * 60)
            return False


def main():
    """Main entry point for the script."""
    ingester = HHSHospitalUtilizationIngester()
    success = ingester.run_ingestion()
    
    if not success:
        exit(1)


if __name__ == "__main__":
    main()
