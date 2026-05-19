"""
WHO FluNet data extractor.

This module handles extraction of global influenza surveillance data
from the WHO FluNet database.
"""

import requests
import pandas as pd
from typing import Optional
from datetime import datetime


class WHOFluNetExtractor:
    """Extract influenza data from WHO FluNet."""
    
    BASE_URL = "https://apps.who.int/flumart/Default?ReportNo=12"
    API_URL = "https://apps.who.int/flumart/Default?ReportNo=12"
    
    def __init__(self):
        """Initialize WHO FluNet extractor."""
        self.session = requests.Session()
    
    def extract_global_data(self, start_date: str, end_date: str) -> pd.DataFrame:
        """
        Extract global influenza data for date range.
        
        Args:
            start_date: Start date in YYYY-MM-DD format
            end_date: End date in YYYY-MM-DD format
            
        Returns:
            DataFrame containing global influenza data
        """
        params = {
            "StartDate": start_date,
            "EndDate": end_date
        }
        
        response = self.session.get(self.API_URL, params=params)
        response.raise_for_status()
        
        # Parse response based on actual API format
        data = response.json() if response.headers.get('content-type') == 'application/json' else response.text
        df = pd.DataFrame(data)
        
        return df
    
    def extract_latest_data(self) -> pd.DataFrame:
        """
        Extract latest available global influenza data.
        
        Returns:
            DataFrame containing latest global data
        """
        end_date = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - pd.Timedelta(days=365)).strftime("%Y-%m-%d")
        
        return self.extract_global_data(start_date, end_date)
    
    def save_to_file(self, df: pd.DataFrame, filepath: str) -> None:
        """
        Save extracted data to file.
        
        Args:
            df: DataFrame to save
            filepath: Path to save file
        """
        df.to_csv(filepath, index=False)
