"""
Database loading utilities.

This module provides functions for loading data into
staging and analytics database tables.
"""

import pandas as pd
from sqlalchemy import create_engine, Engine
from typing import Optional
import logging

logger = logging.getLogger(__name__)


class DatabaseLoader:
    """Load data into database tables."""
    
    def __init__(self, connection_string: str):
        """
        Initialize database loader.
        
        Args:
            connection_string: SQLAlchemy database connection string
        """
        self.engine = create_engine(connection_string)
        self.connection_string = connection_string
    
    def load_to_staging(self, df: pd.DataFrame, table_name: str, schema: str = "staging", 
                       if_exists: str = "append") -> None:
        """
        Load dataframe to staging table.
        
        Args:
            df: DataFrame to load
            table_name: Name of staging table
            schema: Database schema name
            if_exists: What to do if table exists ('fail', 'replace', 'append')
        """
        try:
            full_table_name = f"{schema}.{table_name}"
            df.to_sql(
                table_name,
                self.engine,
                schema=schema,
                if_exists=if_exists,
                index=False,
                method='multi'
            )
            logger.info(f"Successfully loaded {len(df)} rows to {full_table_name}")
        except Exception as e:
            logger.error(f"Error loading data to {full_table_name}: {str(e)}")
            raise
    
    def load_to_analytics(self, df: pd.DataFrame, table_name: str, schema: str = "analytics",
                         if_exists: str = "replace") -> None:
        """
        Load dataframe to analytics table.
        
        Args:
            df: DataFrame to load
            table_name: Name of analytics table
            schema: Database schema name
            if_exists: What to do if table exists ('fail', 'replace', 'append')
        """
        try:
            full_table_name = f"{schema}.{table_name}"
            df.to_sql(
                table_name,
                self.engine,
                schema=schema,
                if_exists=if_exists,
                index=False,
                method='multi'
            )
            logger.info(f"Successfully loaded {len(df)} rows to {full_table_name}")
        except Exception as e:
            logger.error(f"Error loading data to {full_table_name}: {str(e)}")
            raise
    
    def execute_query(self, query: str) -> None:
        """
        Execute SQL query.
        
        Args:
            query: SQL query string
        """
        try:
            with self.engine.connect() as connection:
                connection.execute(query)
                connection.commit()
            logger.info("Query executed successfully")
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise
