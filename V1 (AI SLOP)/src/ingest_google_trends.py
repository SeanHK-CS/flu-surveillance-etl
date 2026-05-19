"""
Google Trends Search Interest Data Ingestion Script

This script:
- Pulls Google Trends search interest for flu-related terms by state
- Aligns dates and locations with CDC/HHS data
- Loads into a staging table
- Handles rate limiting and API constraints
- Logs ingestion success or failure
- Is idempotent if run multiple times
"""

import os
import json
import logging
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
import time

import pandas as pd
from sqlalchemy import create_engine, text, inspect
from sqlalchemy.exc import SQLAlchemyError

# Try to import pytrends
try:
    from pytrends.request import TrendReq
    PYTRENDS_AVAILABLE = True
except ImportError:
    PYTRENDS_AVAILABLE = False
    logger.warning("pytrends not installed. Install with: pip install pytrends")

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
STAGING_TABLE = os.getenv("GOOGLE_TRENDS_STAGING_TABLE", "google_trends_raw")

# Google Trends configuration
SEARCH_TERMS = os.getenv(
    "GOOGLE_TRENDS_TERMS",
    "flu,influenza,flu symptoms,flu vaccine"
).split(",")

# US State codes for Google Trends (ISO 3166-2:US)
US_STATES = [
    'US-AL', 'US-AK', 'US-AZ', 'US-AR', 'US-CA', 'US-CO', 'US-CT', 'US-DE',
    'US-FL', 'US-GA', 'US-HI', 'US-ID', 'US-IL', 'US-IN', 'US-IA', 'US-KS',
    'US-KY', 'US-LA', 'US-ME', 'US-MD', 'US-MA', 'US-MI', 'US-MN', 'US-MS',
    'US-MO', 'US-MT', 'US-NE', 'US-NV', 'US-NH', 'US-NJ', 'US-NM', 'US-NY',
    'US-NC', 'US-ND', 'US-OH', 'US-OK', 'US-OR', 'US-PA', 'US-RI', 'US-SC',
    'US-SD', 'US-TN', 'US-TX', 'US-UT', 'US-VT', 'US-VA', 'US-WA', 'US-WV',
    'US-WI', 'US-WY', 'US-DC'
]

# Warehouse configuration
WAREHOUSE = os.getenv("WAREHOUSE", "postgres").lower()

# Postgres connection
POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    os.getenv("DATABASE_CONNECTION_STRING", "postgresql://user:password@localhost:5432/influenza_db")
)

# BigQuery configuration
BQ_PROJECT = os.getenv("BQ_PROJECT", "")
BQ_DATASET = os.getenv("BQ_DATASET", "influenza_staging")
BQ_LOCATION = os.getenv("BQ_LOCATION", "US")

# API rate limiting
RATE_LIMIT_DELAY = int(os.getenv("GOOGLE_TRENDS_RATE_LIMIT_DELAY", "5"))  # seconds between requests
MAX_RETRIES = int(os.getenv("GOOGLE_TRENDS_MAX_RETRIES", "3"))

# Setup logging
os.makedirs(LOG_DIR, exist_ok=True)
log_file = os.path.join(LOG_DIR, f"google_trends_ingest_{datetime.now().strftime('%Y%m%d')}.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class GoogleTrendsIngester:
    """Main class for ingesting Google Trends search interest data."""
    
    def __init__(self):
        """Initialize the ingester."""
        if not PYTRENDS_AVAILABLE:
            raise ImportError("pytrends is required. Install with: pip install pytrends")
        
        self.raw_dir = Path(RAW_DIR)
        self.raw_dir.mkdir(parents=True, exist_ok=True)
        self.pytrends = TrendReq(hl='en-US', tz=360)  # US timezone
        self.search_terms = [term.strip() for term in SEARCH_TERMS]
        
    def fetch_trends_for_state(self, state_code: str, start_date: datetime, 
                               end_date: datetime, retry_count: int = 0) -> Optional[pd.DataFrame]:
        """
        Fetch Google Trends data for a specific state and date range.
        
        Args:
            state_code: Google Trends state code (e.g., 'US-CA')
            start_date: Start date for trends
            end_date: End date for trends
            retry_count: Current retry attempt
            
        Returns:
            DataFrame with trends data or None if failed
        """
        try:
            # Build keyword list (pytrends supports up to 5 keywords)
            keywords = self.search_terms[:5]  # Limit to 5 terms
            
            # Format dates for pytrends (YYYY-MM-DD)
            timeframe = f"{start_date.strftime('%Y-%m-%d')} {end_date.strftime('%Y-%m-%d')}"
            
            logger.info(f"Fetching trends for {state_code} from {start_date.date()} to {end_date.date()}")
            
            # Build payload
            self.pytrends.build_payload(
                kw_list=keywords,
                geo=state_code,
                timeframe=timeframe,
                cat=0,  # All categories
                gprop=''  # Web search (default)
            )
            
            # Get interest over time
            df = self.pytrends.interest_over_time()
            
            if df.empty:
                logger.warning(f"No data returned for {state_code}")
                return None
            
            # Add state code
            df['state_code'] = state_code
            df['search_date'] = df.index.date
            
            # Reset index to make date a column
            df = df.reset_index()
            
            # Rename columns
            df.columns = [col.lower().replace(' ', '_') for col in df.columns]
            
            # Remove 'ispartial' column if present
            if 'ispartial' in df.columns:
                df = df.drop(columns=['ispartial'])
            
            logger.info(f"Fetched {len(df)} records for {state_code}")
            return df
            
        except Exception as e:
            if retry_count < MAX_RETRIES:
                wait_time = RATE_LIMIT_DELAY * (retry_count + 1)
                logger.warning(f"Error fetching {state_code}, retrying in {wait_time}s: {str(e)}")
                time.sleep(wait_time)
                return self.fetch_trends_for_state(state_code, start_date, end_date, retry_count + 1)
            else:
                logger.error(f"Failed to fetch trends for {state_code} after {MAX_RETRIES} retries: {str(e)}")
                return None
    
    def normalize_state_code(self, google_trends_code: str) -> Optional[str]:
        """
        Convert Google Trends state code to US state abbreviation.
        
        Args:
            google_trends_code: Google Trends code (e.g., 'US-CA')
            
        Returns:
            State abbreviation (e.g., 'CA') or None
        """
        # Remove 'US-' prefix
        if google_trends_code.startswith('US-'):
            return google_trends_code[3:]
        return google_trends_code
    
    def prepare_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare DataFrame with location alignment and date normalization.
        
        Args:
            df: Raw Google Trends DataFrame
            
        Returns:
            Prepared DataFrame aligned with CDC/HHS data
        """
        if df.empty:
            return df
        
        df = df.copy()
        
        # Normalize state code
        if 'state_code' in df.columns:
            df['state_abbreviation'] = df['state_code'].apply(self.normalize_state_code)
        
        # Ensure search_date is datetime
        if 'search_date' in df.columns:
            df['search_date'] = pd.to_datetime(df['search_date'])
        elif 'date' in df.columns:
            df['search_date'] = pd.to_datetime(df['date'])
        
        # Calculate epiweek for alignment with CDC data
        if 'search_date' in df.columns:
            df['year'] = df['search_date'].dt.year
            df['week_number'] = df['search_date'].dt.isocalendar().week
            
            # Calculate epiweek (YYYYWW format)
            def date_to_epiweek(date_val):
                if pd.isna(date_val):
                    return None
                year = date_val.year
                week = date_val.isocalendar()[1]
                # Handle year boundary
                if week == 1 and date_val.month == 12:
                    year += 1
                elif week >= 52 and date_val.month == 1:
                    year -= 1
                return int(f"{year}{week:02d}")
            
            df['epiweek'] = df['search_date'].apply(date_to_epiweek)
        
        # Add metadata
        df['ingestion_timestamp'] = datetime.now()
        df['data_source'] = 'google_trends'
        
        # Melt search term columns into rows (if multiple terms)
        search_term_cols = [col for col in df.columns if col not in 
                           ['state_code', 'state_abbreviation', 'search_date', 'date', 
                            'year', 'week_number', 'epiweek', 'ingestion_timestamp', 
                            'data_source', 'ispartial']]
        
        # If we have multiple search terms, create a normalized structure
        if len(search_term_cols) > 1:
            # Create a combined interest score (average of all terms)
            df['search_interest'] = df[search_term_cols].mean(axis=1)
            df['search_terms'] = ','.join(self.search_terms[:5])
        else:
            # Single term
            if search_term_cols:
                df['search_interest'] = df[search_term_cols[0]]
                df['search_terms'] = search_term_cols[0]
        
        # Select final columns
        final_cols = ['state_abbreviation', 'search_date', 'year', 'week_number', 
                      'epiweek', 'search_interest', 'search_terms', 
                      'ingestion_timestamp', 'data_source']
        df = df[[col for col in final_cols if col in df.columns]]
        
        return df
    
    def save_raw_file(self, df: pd.DataFrame, state_code: str, date: datetime) -> str:
        """
        Save raw data file partitioned by date.
        
        Args:
            df: DataFrame to save
            state_code: State code for filename
            date: Date for partitioning
            
        Returns:
            Path to saved file
        """
        # Create date-partitioned directory
        date_partition = self.raw_dir / "google_trends" / date.strftime("%Y") / date.strftime("%m") / date.strftime("%d")
        date_partition.mkdir(parents=True, exist_ok=True)
        
        # Generate file path
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        state_abbr = self.normalize_state_code(state_code) or state_code
        filename = f"google_trends_{state_abbr}_{date.strftime('%Y%m%d')}_{timestamp}.csv"
        file_path = date_partition / filename
        
        # Save CSV
        df.to_csv(file_path, index=False)
        logger.info(f"Saved raw CSV to {file_path} ({len(df)} rows)")
        
        # Save metadata JSON
        metadata = {
            "source": "Google Trends",
            "download_date": datetime.now().isoformat(),
            "data_date": date.isoformat(),
            "state_code": state_code,
            "row_count": len(df),
            "search_terms": self.search_terms,
            "file_path": str(file_path)
        }
        metadata_path = file_path.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        return str(file_path)
    
    def get_schema_mapping(self, df: pd.DataFrame) -> Dict[str, str]:
        """Infer SQL schema from DataFrame."""
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
        """Create or alter Postgres table to match DataFrame schema."""
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
        """Load DataFrame to Postgres with idempotency."""
        if df.empty:
            logger.warning("DataFrame is empty, nothing to load")
            return
        
        self.ensure_postgres_table(engine, table_name, df)
        
        # Idempotency: Delete existing records for same date/state
        if 'search_date' in df.columns and 'state_abbreviation' in df.columns:
            dates = df['search_date'].dt.date.unique().tolist()
            states = df['state_abbreviation'].unique().tolist()
            
            with engine.begin() as conn:
                delete_sql = text(f"""
                    DELETE FROM {table_name} 
                    WHERE search_date::DATE IN :dates 
                    AND state_abbreviation IN :states
                """)
                conn.execute(delete_sql, {"dates": tuple(dates), "states": tuple(states)})
                logger.info(f"Deleted existing records for {len(dates)} dates and {len(states)} states")
        
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
        """Load DataFrame to BigQuery."""
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
        
        if 'search_date' in df.columns:
            job_config.time_partitioning = bigquery.TimePartitioning(
                field="search_date",
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
    
    def run_ingestion(self, start_date: Optional[datetime] = None, 
                     end_date: Optional[datetime] = None,
                     states: Optional[List[str]] = None) -> bool:
        """
        Run the complete ingestion process.
        
        Args:
            start_date: Start date for data (default: 30 days ago)
            end_date: End date for data (default: today)
            states: List of state codes to process (default: all US states)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            logger.info("=" * 60)
            logger.info("Starting Google Trends data ingestion")
            logger.info(f"Search terms: {self.search_terms}")
            logger.info("=" * 60)
            
            # Set default dates
            if end_date is None:
                end_date = datetime.now()
            if start_date is None:
                start_date = end_date - timedelta(days=30)
            
            # Set default states
            if states is None:
                states = US_STATES
            
            # Limit date range (Google Trends has limits)
            if (end_date - start_date).days > 270:  # ~9 months max
                logger.warning(f"Date range exceeds 270 days, limiting to last 270 days")
                start_date = end_date - timedelta(days=270)
            
            total_records = 0
            successful_states = 0
            failed_states = 0
            
            # Process each state
            for i, state_code in enumerate(states):
                try:
                    logger.info(f"Processing {state_code} ({i+1}/{len(states)})")
                    
                    # Fetch trends
                    df = self.fetch_trends_for_state(state_code, start_date, end_date)
                    
                    if df is None or df.empty:
                        failed_states += 1
                        continue
                    
                    # Prepare DataFrame
                    df_prepared = self.prepare_dataframe(df)
                    
                    if df_prepared.empty:
                        logger.warning(f"No data after preparation for {state_code}")
                        failed_states += 1
                        continue
                    
                    # Save raw file
                    self.save_raw_file(df_prepared, state_code, end_date)
                    
                    # Load to warehouse
                    full_table_name = f"{STAGING_SCHEMA}.{STAGING_TABLE}"
                    
                    if WAREHOUSE == "postgres":
                        engine = create_engine(POSTGRES_URL)
                        self.load_to_postgres(df_prepared, full_table_name, engine)
                    elif WAREHOUSE == "bigquery":
                        self.load_to_bigquery(df_prepared, STAGING_TABLE)
                    else:
                        raise ValueError(f"Unknown warehouse: {WAREHOUSE}")
                    
                    total_records += len(df_prepared)
                    successful_states += 1
                    
                    # Rate limiting
                    if i < len(states) - 1:  # Don't wait after last state
                        time.sleep(RATE_LIMIT_DELAY)
                    
                except Exception as e:
                    failed_states += 1
                    logger.error(f"Error processing {state_code}: {e}", exc_info=True)
                    continue
            
            logger.info("=" * 60)
            logger.info(f"Google Trends ingestion completed")
            logger.info(f"Successful states: {successful_states}/{len(states)}")
            logger.info(f"Failed states: {failed_states}")
            logger.info(f"Total records loaded: {total_records}")
            logger.info("=" * 60)
            
            return failed_states == 0
            
        except Exception as e:
            logger.error("=" * 60)
            logger.error(f"Google Trends ingestion FAILED: {e}", exc_info=True)
            logger.error("=" * 60)
            return False


def main():
    """Main entry point for the script."""
    ingester = GoogleTrendsIngester()
    success = ingester.run_ingestion()
    
    if not success:
        exit(1)


if __name__ == "__main__":
    main()
