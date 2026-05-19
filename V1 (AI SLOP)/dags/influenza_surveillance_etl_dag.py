"""
Apache Airflow DAG for Influenza Surveillance ETL Pipeline

This DAG orchestrates the complete ETL process:
1. Ingest CDC FluView data (daily)
2. Ingest HHS hospital utilization data (daily)
3. Transform staging data to fact tables
4. Calculate rolling averages and trends
5. Handle errors with retries and notifications

Supports backfills for historical dates via Airflow's backfill functionality.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
# PostgresOperator is deprecated in Airflow 2.0+, using PythonOperator for SQL instead
from airflow.utils.dates import days_ago
from airflow.exceptions import AirflowException
import logging
import os
import sys

# Configure logging
logger = logging.getLogger(__name__)

# Default arguments for the DAG
default_args = {
    'owner': 'data_engineering',
    'depends_on_past': False,  # Set to True if you want tasks to depend on previous run
    'email_on_failure': False,  # Set to True if email is configured
    'email_on_retry': False,
    'retries': 3,  # Number of retries on failure
    'retry_delay': timedelta(minutes=10),  # Wait 10 minutes between retries
    'retry_exponential_backoff': True,  # Exponential backoff for retries
    'max_retry_delay': timedelta(hours=1),
}

# Define the DAG
dag = DAG(
    'influenza_surveillance_etl',
    default_args=default_args,
    description='Complete ETL pipeline for influenza surveillance data',
    schedule_interval='@daily',  # Run daily at midnight
    start_date=days_ago(2),  # Start 2 days ago to allow backfills
    catchup=True,  # Enable backfills for historical dates
    max_active_runs=1,  # Only one DAG run at a time
    tags=['influenza', 'surveillance', 'etl', 'health', 'cdc', 'hhs'],
    params={
        'backfill_days': 7,  # Default lookback for late-arriving data
    }
)


# ============================================================================
# Helper Functions
# ============================================================================

def setup_paths():
    """Add src directory to Python path."""
    dag_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(dag_dir)
    src_path = os.path.join(project_root, 'src')
    if src_path not in sys.path:
        sys.path.insert(0, src_path)
    return project_root


def notify_failure(context):
    """Send notification on task failure (simple print/log for now)."""
    task_instance = context.get('task_instance')
    task_id = task_instance.task_id
    execution_date = context.get('execution_date')
    exception = context.get('exception')
    
    error_message = f"""
    ========================================================================
    TASK FAILURE NOTIFICATION
    ========================================================================
    Task ID: {task_id}
    Execution Date: {execution_date}
    Exception: {exception}
    ========================================================================
    """
    
    logger.error(error_message)
    print(error_message)
    
    # In production, you could add:
    # - Email notifications
    # - Slack/Teams webhooks
    # - PagerDuty alerts
    # - SNS/SQS messages


# ============================================================================
# Task 1: Ingest CDC FluView Data
# ============================================================================

def ingest_cdc_fluview(**context):
    """Ingest CDC FluView data using the ingestion script."""
    try:
        setup_paths()
        
        from ingest_cdc_fluview import FluViewIngester
        
        logger.info("Starting CDC FluView data ingestion...")
        logger.info(f"Execution date: {context.get('execution_date')}")
        
        # Initialize ingester
        ingester = FluViewIngester()
        
        # Run ingestion
        success = ingester.run_ingestion()
        
        if not success:
            raise AirflowException("CDC FluView ingestion failed")
        
        logger.info("CDC FluView ingestion completed successfully")
        return "CDC FluView ingestion successful"
        
    except Exception as e:
        logger.error(f"CDC FluView ingestion error: {str(e)}", exc_info=True)
        notify_failure(context)
        raise


ingest_cdc_task = PythonOperator(
    task_id='ingest_cdc_fluview',
    python_callable=ingest_cdc_fluview,
    on_failure_callback=notify_failure,
    dag=dag,
)


# ============================================================================
# Task 2: Ingest HHS Hospital Utilization Data
# ============================================================================

def ingest_hhs_hospital(**context):
    """Ingest HHS hospital utilization data using the ingestion script."""
    try:
        setup_paths()
        
        from ingest_hhs_hospital_utilization import HHSHospitalUtilizationIngester
        
        logger.info("Starting HHS hospital utilization data ingestion...")
        logger.info(f"Execution date: {context.get('execution_date')}")
        
        # Get lookback days from DAG params or environment
        lookback_days = int(context.get('params', {}).get('backfill_days', 
                          os.getenv('HHS_LOOKBACK_DAYS', '7')))
        
        # Initialize ingester
        ingester = HHSHospitalUtilizationIngester()
        
        # Run ingestion with lookback for late-arriving data
        success = ingester.run_ingestion(lookback_days=lookback_days)
        
        if not success:
            raise AirflowException("HHS hospital utilization ingestion failed")
        
        logger.info("HHS hospital utilization ingestion completed successfully")
        return "HHS hospital utilization ingestion successful"
        
    except Exception as e:
        logger.error(f"HHS hospital utilization ingestion error: {str(e)}", exc_info=True)
        notify_failure(context)
        raise


ingest_hhs_task = PythonOperator(
    task_id='ingest_hhs_hospital',
    python_callable=ingest_hhs_hospital,
    on_failure_callback=notify_failure,
    dag=dag,
)


# ============================================================================
# Task 3: Transform CDC Staging to Facts
# ============================================================================

def transform_cdc_to_facts(**context):
    """Transform CDC FluView staging data to fact tables."""
    try:
        setup_paths()
        
        from sqlalchemy import create_engine, text
        
        logger.info("Starting CDC FluView transformation to fact tables...")
        
        # Get database connection from environment
        db_url = os.getenv('POSTGRES_URL', 
                          os.getenv('DATABASE_CONNECTION_STRING',
                                   'postgresql://user:password@localhost:5432/influenza_db'))
        
        engine = create_engine(db_url)
        
        # Execute transformation function
        with engine.connect() as conn:
            result = conn.execute(text("SELECT * FROM transform.load_cdc_fluview_to_facts()"))
            stats = result.fetchone()
            
            logger.info(f"CDC transformation stats: processed={stats[0]}, "
                      f"inserted={stats[1]}, updated={stats[2]}, "
                      f"skipped={stats[3]}, errors={stats[4]}")
            
            if stats[4] > 0:  # errors > 0
                logger.warning(f"CDC transformation completed with {stats[4]} errors")
            
            if stats[0] == 0:
                logger.warning("No CDC data processed - this may be normal if no new data")
        
        logger.info("CDC FluView transformation completed successfully")
        return "CDC transformation successful"
        
    except Exception as e:
        logger.error(f"CDC transformation error: {str(e)}", exc_info=True)
        notify_failure(context)
        raise


transform_cdc_task = PythonOperator(
    task_id='transform_cdc_to_facts',
    python_callable=transform_cdc_to_facts,
    on_failure_callback=notify_failure,
    dag=dag,
)


# ============================================================================
# Task 4: Transform HHS Staging to Facts
# ============================================================================

def transform_hhs_to_facts(**context):
    """Transform HHS hospital utilization staging data to fact tables."""
    try:
        setup_paths()
        
        from sqlalchemy import create_engine, text
        
        logger.info("Starting HHS hospital utilization transformation to fact tables...")
        
        # Get database connection
        db_url = os.getenv('POSTGRES_URL',
                          os.getenv('DATABASE_CONNECTION_STRING',
                                   'postgresql://user:password@localhost:5432/influenza_db'))
        
        engine = create_engine(db_url)
        
        # Execute transformation function
        with engine.connect() as conn:
            result = conn.execute(text("SELECT * FROM transform.load_hhs_to_facts()"))
            stats = result.fetchone()
            
            logger.info(f"HHS transformation stats: processed={stats[0]}, "
                      f"inserted={stats[1]}, updated={stats[2]}, "
                      f"skipped={stats[3]}, errors={stats[4]}")
            
            if stats[4] > 0:
                logger.warning(f"HHS transformation completed with {stats[4]} errors")
            
            if stats[0] == 0:
                logger.warning("No HHS data processed - this may be normal if no new data")
        
        logger.info("HHS hospital utilization transformation completed successfully")
        return "HHS transformation successful"
        
    except Exception as e:
        logger.error(f"HHS transformation error: {str(e)}", exc_info=True)
        notify_failure(context)
        raise


transform_hhs_task = PythonOperator(
    task_id='transform_hhs_to_facts',
    python_callable=transform_hhs_to_facts,
    on_failure_callback=notify_failure,
    dag=dag,
)


# ============================================================================
# Task 5: Calculate Rolling Averages and Trends
# ============================================================================

def calculate_rolling_averages_and_trends(**context):
    """Calculate rolling averages and trend flags for fact tables."""
    try:
        setup_paths()
        
        from sqlalchemy import create_engine, text
        
        logger.info("Starting rolling averages and trend calculations...")
        
        # Get database connection
        db_url = os.getenv('POSTGRES_URL',
                          os.getenv('DATABASE_CONNECTION_STRING',
                                   'postgresql://user:password@localhost:5432/influenza_db'))
        
        engine = create_engine(db_url)
        
        with engine.connect() as conn:
            # Update rolling averages for weekly cases
            logger.info("Calculating rolling averages for weekly cases...")
            result = conn.execute(text("SELECT * FROM transform.update_rolling_averages_weekly()"))
            stats_weekly = result.fetchone()
            logger.info(f"Weekly averages: updated={stats_weekly[0]}, errors={stats_weekly[1]}")
            
            # Update rolling averages for daily hospitalizations
            logger.info("Calculating rolling averages for daily hospitalizations...")
            result = conn.execute(text("SELECT * FROM transform.update_rolling_averages_daily()"))
            stats_daily = result.fetchone()
            logger.info(f"Daily averages: updated={stats_daily[0]}, errors={stats_daily[1]}")
            
            # Update trend flags for weekly cases
            logger.info("Calculating trend flags for weekly cases...")
            result = conn.execute(text("SELECT * FROM transform.update_trend_flags_weekly()"))
            stats_trends_weekly = result.fetchone()
            logger.info(f"Weekly trends: updated={stats_trends_weekly[0]}, errors={stats_trends_weekly[1]}")
            
            # Update trend flags for daily hospitalizations
            logger.info("Calculating trend flags for daily hospitalizations...")
            result = conn.execute(text("SELECT * FROM transform.update_trend_flags_daily()"))
            stats_trends_daily = result.fetchone()
            logger.info(f"Daily trends: updated={stats_trends_daily[0]}, errors={stats_trends_daily[1]}")
            
            # Check for errors
            total_errors = (stats_weekly[1] + stats_daily[1] + 
                           stats_trends_weekly[1] + stats_trends_daily[1])
            
            if total_errors > 0:
                logger.warning(f"Rolling averages/trends calculation completed with {total_errors} errors")
        
        logger.info("Rolling averages and trend calculations completed successfully")
        return "Rolling averages and trends calculation successful"
        
    except Exception as e:
        logger.error(f"Rolling averages/trends calculation error: {str(e)}", exc_info=True)
        notify_failure(context)
        raise


calculate_metrics_task = PythonOperator(
    task_id='calculate_rolling_averages_and_trends',
    python_callable=calculate_rolling_averages_and_trends,
    on_failure_callback=notify_failure,
    dag=dag,
)


# ============================================================================
# Task 6: Data Quality Validation (Optional)
# ============================================================================

def data_quality_validation(**context):
    """Perform data quality checks on fact tables."""
    try:
        setup_paths()
        
        from sqlalchemy import create_engine, text
        
        logger.info("Starting data quality validation...")
        
        db_url = os.getenv('POSTGRES_URL',
                          os.getenv('DATABASE_CONNECTION_STRING',
                                   'postgresql://user:password@localhost:5432/influenza_db'))
        
        engine = create_engine(db_url)
        
        with engine.connect() as conn:
            # Check for recent data
            result = conn.execute(text("""
                SELECT COUNT(*) as recent_records
                FROM facts.fact_flu_cases_weekly f
                JOIN dimensions.dim_date d ON f.date_id = d.date_id
                WHERE d.full_date >= CURRENT_DATE - INTERVAL '7 days'
            """))
            recent_count = result.scalar()
            logger.info(f"Recent weekly case records (last 7 days): {recent_count}")
            
            # Check for null values in key metrics
            result = conn.execute(text("""
                SELECT COUNT(*) as null_cases
                FROM facts.fact_flu_cases_weekly
                WHERE positive_cases IS NULL OR total_tests IS NULL
            """))
            null_count = result.scalar()
            if null_count > 0:
                logger.warning(f"Found {null_count} records with null key metrics")
            
            # Check hospital data
            result = conn.execute(text("""
                SELECT COUNT(*) as recent_hosp_records
                FROM facts.fact_flu_hospitalizations_daily f
                JOIN dimensions.dim_date d ON f.date_id = d.date_id
                WHERE d.full_date >= CURRENT_DATE - INTERVAL '7 days'
            """))
            recent_hosp_count = result.scalar()
            logger.info(f"Recent daily hospitalization records (last 7 days): {recent_hosp_count}")
        
        logger.info("Data quality validation completed")
        return "Data quality validation successful"
        
    except Exception as e:
        logger.error(f"Data quality validation error: {str(e)}", exc_info=True)
        # Don't fail the DAG on quality check failures, just log
        logger.warning("Data quality validation encountered issues but continuing...")
        return "Data quality validation completed with warnings"


quality_check_task = PythonOperator(
    task_id='data_quality_validation',
    python_callable=data_quality_validation,
    dag=dag,
)


# ============================================================================
# Task Dependencies
# ============================================================================

# Ingestions can run in parallel
[ingest_cdc_task, ingest_hhs_task] >> [transform_cdc_task, transform_hhs_task]

# Transformations must complete before calculating metrics
[transform_cdc_task, transform_hhs_task] >> calculate_metrics_task

# Quality checks run after metrics calculation
calculate_metrics_task >> quality_check_task
