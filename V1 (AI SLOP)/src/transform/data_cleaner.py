"""
Data cleaning and validation utilities.

This module provides functions for cleaning and validating
influenza surveillance data.
"""

import pandas as pd
from typing import Dict, List
import numpy as np


class DataCleaner:
    """Clean and validate influenza surveillance data."""
    
    def __init__(self):
        """Initialize data cleaner."""
        self.validation_errors = []
    
    def clean_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Apply standard cleaning operations to dataframe.
        
        Args:
            df: Raw dataframe to clean
            
        Returns:
            Cleaned dataframe
        """
        df_cleaned = df.copy()
        
        # Remove duplicate rows
        df_cleaned = df_cleaned.drop_duplicates()
        
        # Standardize column names (lowercase, replace spaces with underscores)
        df_cleaned.columns = df_cleaned.columns.str.lower().str.replace(' ', '_')
        
        # Handle missing values in numeric columns
        numeric_columns = df_cleaned.select_dtypes(include=[np.number]).columns
        df_cleaned[numeric_columns] = df_cleaned[numeric_columns].fillna(0)
        
        return df_cleaned
    
    def validate_data(self, df: pd.DataFrame, required_columns: List[str]) -> bool:
        """
        Validate that dataframe contains required columns and data quality checks.
        
        Args:
            df: Dataframe to validate
            required_columns: List of required column names
            
        Returns:
            True if validation passes, False otherwise
        """
        self.validation_errors = []
        
        # Check required columns
        missing_columns = set(required_columns) - set(df.columns)
        if missing_columns:
            self.validation_errors.append(f"Missing required columns: {missing_columns}")
            return False
        
        # Check for empty dataframe
        if df.empty:
            self.validation_errors.append("Dataframe is empty")
            return False
        
        # Check for negative values in count columns
        count_columns = [col for col in df.columns if 'count' in col or 'cases' in col]
        for col in count_columns:
            if col in df.columns and (df[col] < 0).any():
                self.validation_errors.append(f"Negative values found in {col}")
        
        return len(self.validation_errors) == 0
    
    def get_validation_errors(self) -> List[str]:
        """
        Get list of validation errors.
        
        Returns:
            List of validation error messages
        """
        return self.validation_errors
    
    def standardize_dates(self, df: pd.DataFrame, date_column: str) -> pd.DataFrame:
        """
        Standardize date column format.
        
        Args:
            df: Dataframe with date column
            date_column: Name of date column
            
        Returns:
            Dataframe with standardized dates
        """
        df_copy = df.copy()
        
        if date_column in df_copy.columns:
            df_copy[date_column] = pd.to_datetime(df_copy[date_column], errors='coerce')
        
        return df_copy
