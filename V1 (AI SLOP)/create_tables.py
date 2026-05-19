"""
Python script to create all database tables.
This is useful if you don't have psql installed locally.
"""

import os
import sys
from pathlib import Path
from sqlalchemy import create_engine, text

def create_tables():
    """Create all database tables from SQL files."""
    
    # Get database URL
    db_url = os.getenv('POSTGRES_URL') or os.getenv('DATABASE_CONNECTION_STRING')
    if not db_url:
        print("ERROR: POSTGRES_URL environment variable not set!")
        print("Set it with: $env:POSTGRES_URL='postgresql://postgres:password@localhost:5432/influenza_db'")
        sys.exit(1)
    
    print(f"Connecting to database...")
    engine = create_engine(db_url)
    
    # First, create all schemas
    print("\nCreating schemas...")
    schemas = ['staging', 'dimensions', 'facts', 'transform', 'validation', 'analytics']
    with engine.connect() as conn:
        for schema in schemas:
            try:
                conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema}"))
                conn.commit()
                print(f"  [OK] Schema '{schema}' created")
            except Exception as e:
                print(f"  [WARNING] Schema '{schema}': {str(e)[:100]}")
    
    # SQL files to execute in order
    sql_files = [
        'sql/staging/create_staging_tables.sql',
        'sql/dimensions/create_dimension_tables.sql',
        'sql/dimensions/seed_dimension_data.sql',
        'sql/facts/create_fact_tables.sql',
        'sql/transform/utilities.sql',
        'sql/transform/transform_google_trends_to_facts.sql',
        'sql/transform/calculate_search_interest_metrics.sql',
    ]
    
    project_root = Path(__file__).parent
    
    for sql_file in sql_files:
        file_path = project_root / sql_file
        
        if not file_path.exists():
            print(f"WARNING: {sql_file} not found, skipping...")
            continue
        
        print(f"\nExecuting {sql_file}...")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                sql_content = f.read()
            
            # Split by semicolons and execute each statement
            statements = [s.strip() for s in sql_content.split(';') if s.strip() and not s.strip().startswith('--')]
            
            with engine.connect() as conn:
                for statement in statements:
                    if statement:
                        try:
                            conn.execute(text(statement))
                            conn.commit()
                        except Exception as e:
                            # Some errors are OK (like "already exists")
                            if 'already exists' in str(e).lower() or 'duplicate' in str(e).lower():
                                print(f"  (already exists, skipping)")
                            else:
                                print(f"  WARNING: {str(e)[:100]}")
            
            print(f"  [OK] Completed {sql_file}")
            
        except Exception as e:
            print(f"  [ERROR] Error executing {sql_file}: {e}")
            # Continue with next file
    
    print("\n" + "="*60)
    print("Table creation complete!")
    print("="*60)
    print("\nNext steps:")
    print("1. Verify tables: python -c \"from sqlalchemy import create_engine, inspect; e=create_engine('$env:POSTGRES_URL'); print(inspect(e).get_table_names())\"")
    print("2. Run test: python run_google_trends_test.py")

if __name__ == "__main__":
    create_tables()
