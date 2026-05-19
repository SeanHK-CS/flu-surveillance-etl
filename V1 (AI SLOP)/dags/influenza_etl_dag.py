"""
Apache Airflow DAG for Influenza Surveillance ETL Pipeline.

This DAG orchestrates the complete ETL process:
1. Extract data from various sources
2. Transform and clean the data
3. Load data into staging and analytics tables
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

# Default arguments for the DAG
default_args = {
    'owner': 'data_engineering',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
dag = DAG(
    'influenza_surveillance_etl',
    default_args=default_args,
    description='ETL pipeline for influenza surveillance data',
    schedule_interval='@daily',  # Run daily
    start_date=days_ago(1),
    catchup=False,
    tags=['influenza', 'surveillance', 'etl', 'health'],
)

# Task 1: Extract CDC FluView data
def extract_cdc_data(**context):
    """Extract data from CDC FluView API."""
    import sys
    import os
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    from extract.cdc_extractor import CDCFluViewExtractor
    
    extractor = CDCFluViewExtractor()
    df = extractor.extract_current_season()
    
    # Save to temporary location
    output_path = '/tmp/cdc_fluview_data.csv'
    extractor.save_to_file(df, output_path)
    
    return output_path

extract_cdc_task = PythonOperator(
    task_id='extract_cdc_fluview',
    python_callable=extract_cdc_data,
    dag=dag,
)

# Task 2: Extract WHO FluNet data
def extract_who_data(**context):
    """Extract data from WHO FluNet."""
    import sys
    import os
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    from extract.who_extractor import WHOFluNetExtractor
    
    extractor = WHOFluNetExtractor()
    df = extractor.extract_latest_data()
    
    # Save to temporary location
    output_path = '/tmp/who_flunet_data.csv'
    extractor.save_to_file(df, output_path)
    
    return output_path

extract_who_task = PythonOperator(
    task_id='extract_who_flunet',
    python_callable=extract_who_data,
    dag=dag,
)

# Task 3: Transform and load CDC data
def transform_load_cdc(**context):
    """Transform and load CDC data to staging."""
    import sys
    import os
    import pandas as pd
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    from transform.data_cleaner import DataCleaner
    from load.database_loader import DatabaseLoader
    
    # Get connection string from Airflow variables or environment
    connection_string = os.getenv('DATABASE_CONNECTION_STRING', 
                                  'postgresql://user:password@localhost:5432/influenza_db')
    
    # Load and clean data
    df = pd.read_csv('/tmp/cdc_fluview_data.csv')
    cleaner = DataCleaner()
    df_cleaned = cleaner.clean_dataframe(df)
    
    # Load to staging
    loader = DatabaseLoader(connection_string)
    loader.load_to_staging(df_cleaned, 'fluview_raw', schema='staging')

transform_load_cdc_task = PythonOperator(
    task_id='transform_load_cdc',
    python_callable=transform_load_cdc,
    dag=dag,
)

# Task 4: Transform and load WHO data
def transform_load_who(**context):
    """Transform and load WHO data to staging."""
    import sys
    import os
    import pandas as pd
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    from transform.data_cleaner import DataCleaner
    from load.database_loader import DatabaseLoader
    
    # Get connection string from Airflow variables or environment
    connection_string = os.getenv('DATABASE_CONNECTION_STRING',
                                  'postgresql://user:password@localhost:5432/influenza_db')
    
    # Load and clean data
    df = pd.read_csv('/tmp/who_flunet_data.csv')
    cleaner = DataCleaner()
    df_cleaned = cleaner.clean_dataframe(df)
    
    # Load to staging
    loader = DatabaseLoader(connection_string)
    loader.load_to_staging(df_cleaned, 'flunet_raw', schema='staging')

transform_load_who_task = PythonOperator(
    task_id='transform_load_who',
    python_callable=transform_load_who,
    dag=dag,
)

# Task 5: Run analytics transformations
def run_analytics_transformations(**context):
    """Run SQL transformations to create analytics tables."""
    import sys
    import os
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    from load.database_loader import DatabaseLoader
    
    connection_string = os.getenv('DATABASE_CONNECTION_STRING',
                                  'postgresql://user:password@localhost:5432/influenza_db')
    loader = DatabaseLoader(connection_string)
    
    # Execute analytics SQL scripts
    sql_dir = os.path.join(os.path.dirname(__file__), '..', 'sql', 'analytics')
    
    # This would iterate through SQL files and execute them
    # For now, this is a placeholder
    print("Running analytics transformations...")

run_analytics_task = PythonOperator(
    task_id='run_analytics_transformations',
    python_callable=run_analytics_transformations,
    dag=dag,
)

# Task 6: Data quality checks
def data_quality_checks(**context):
    """Perform data quality validation."""
    import sys
    import os
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
    
    print("Running data quality checks...")
    # Implement data quality validation logic
    return True

quality_checks_task = PythonOperator(
    task_id='data_quality_checks',
    python_callable=data_quality_checks,
    dag=dag,
)

# Define task dependencies
[extract_cdc_task, extract_who_task] >> [transform_load_cdc_task, transform_load_who_task]
[transform_load_cdc_task, transform_load_who_task] >> run_analytics_task
run_analytics_task >> quality_checks_task
