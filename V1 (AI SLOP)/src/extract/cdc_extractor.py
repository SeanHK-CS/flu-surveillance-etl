"""
CDC FluView data extractor.

This module handles extraction of influenza surveillance data
from the CDC FluView API.
"""

import requests
import pandas as pd
from typing import Dict, Optional
from datetime import datetime


class CDCFluViewExtractor:
    """Extract influenza data from CDC FluView API."""
    
    BASE_URL = "https://gis.cdc.gov/grasp/fluview/fluportaldashboard.html"
    API_URL = "https://gis.cdc.gov/grasp/flu2/GetPhase02InitApp"
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize CDC FluView extractor.
        
        Args:
            api_key: Optional API key for authenticated requests
        """
        self.api_key = api_key
        self.session = requests.Session()
        if api_key:
            self.session.headers.update({"Authorization": f"Bearer {api_key}"})
    
    def extract_weekly_data(self, year: int, week: int) -> pd.DataFrame:
        """
        Extract weekly influenza data.
        
        Args:
            year: Year of data
            week: Week number
            
        Returns:
            DataFrame containing weekly influenza data
        """
        params = {
            "year": year,
            "week": week
        }
        
        response = self.session.get(self.API_URL, params=params)
        response.raise_for_status()
        
        data = response.json()
        df = pd.DataFrame(data)
        
        return df
    
    def extract_current_season(self) -> pd.DataFrame:
        """
        Extract data for the current influenza season.
        
        Returns:
            DataFrame containing current season data
        """
        current_year = datetime.now().year
        current_week = datetime.now().isocalendar()[1]
        
        return self.extract_weekly_data(current_year, current_week)
    
    def save_to_file(self, df: pd.DataFrame, filepath: str) -> None:
        """
        Save extracted data to file.
        
        Args:
            df: DataFrame to save
            filepath: Path to save file
        """
        df.to_csv(filepath, index=False)
