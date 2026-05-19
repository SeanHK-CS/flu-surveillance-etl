"""
Python script to run common analyses on the influenza surveillance data.
This script demonstrates how to query the database and create visualizations.
"""

import os
import sys
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine
from datetime import datetime, timedelta

# Configuration
POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    os.getenv("DATABASE_CONNECTION_STRING", "postgresql://postgres:influenza123@localhost:5432/influenza_db")
)

def run_query(query_name, query):
    """Run a SQL query and return results as DataFrame."""
    engine = create_engine(POSTGRES_URL)
    print(f"\n{'='*60}")
    print(f"Running: {query_name}")
    print('='*60)
    df = pd.read_sql(query, engine)
    print(f"\nResults ({len(df)} rows):")
    print(df.to_string())
    return df

def analyze_state_comparison():
    """Compare search interest across states."""
    query = """
    SELECT 
        l.state_name,
        l.region,
        AVG(f.search_interest) as avg_interest,
        MAX(f.search_interest) as peak_interest,
        COUNT(*) as days_with_data,
        MAX(d.full_date) as latest_date
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY l.state_name, l.region
    ORDER BY avg_interest DESC;
    """
    return run_query("State Comparison", query)

def analyze_trends():
    """Analyze rising vs declining trends."""
    query = """
    SELECT 
        l.state_name,
        COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_days,
        COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as declining_days,
        COUNT(*) FILTER (WHERE f.trend_flag = 'stable') as stable_days,
        AVG(f.search_interest) as avg_interest
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
    GROUP BY l.state_name
    ORDER BY rising_days DESC;
    """
    return run_query("Trend Analysis", query)

def analyze_time_series():
    """Get time series data for visualization."""
    query = """
    SELECT 
        d.full_date,
        l.state_name,
        f.search_interest,
        f.search_interest_7day_avg,
        f.trend_flag
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY l.state_name, d.full_date;
    """
    return run_query("Time Series Data", query)

def create_visualizations(df_time_series):
    """Create visualizations from the data."""
    if df_time_series.empty:
        print("\nNo data available for visualization.")
        return
    
    # Set style
    sns.set_style("whitegrid")
    plt.rcParams['figure.figsize'] = (14, 8)
    
    # 1. Time series plot by state
    fig, ax = plt.subplots()
    for state in df_time_series['state_name'].unique():
        state_data = df_time_series[df_time_series['state_name'] == state]
        ax.plot(state_data['full_date'], state_data['search_interest'], 
                label=state, marker='o', markersize=4)
    
    ax.set_xlabel('Date')
    ax.set_ylabel('Search Interest')
    ax.set_title('Google Trends Search Interest Over Time by State')
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig('analysis_search_interest_timeseries.png', dpi=300, bbox_inches='tight')
    print("\n✓ Saved: analysis_search_interest_timeseries.png")
    
    # 2. 7-day moving average comparison
    fig, ax = plt.subplots()
    for state in df_time_series['state_name'].unique():
        state_data = df_time_series[df_time_series['state_name'] == state]
        ax.plot(state_data['full_date'], state_data['search_interest_7day_avg'], 
                label=f"{state} (7-day avg)", linestyle='--', linewidth=2)
    
    ax.set_xlabel('Date')
    ax.set_ylabel('Search Interest (7-day average)')
    ax.set_title('7-Day Moving Average: Search Interest by State')
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig('analysis_7day_average.png', dpi=300, bbox_inches='tight')
    print("✓ Saved: analysis_7day_average.png")
    
    plt.close('all')

def analyze_dashboard_metrics():
    """Get dashboard summary metrics."""
    query = """
    SELECT 
        COUNT(DISTINCT l.state_code) as states_tracked,
        COUNT(*) as total_observations,
        ROUND(AVG(f.search_interest), 2) as national_avg_interest,
        COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as states_rising,
        COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as states_declining,
        COUNT(*) FILTER (WHERE f.trend_flag = 'stable') as states_stable,
        MAX(d.full_date) as latest_data_date,
        MIN(d.full_date) as earliest_data_date
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id;
    """
    return run_query("Dashboard Metrics", query)

def analyze_early_warnings():
    """Identify states with sudden spikes."""
    query = """
    SELECT 
        l.state_name,
        d.full_date,
        f.search_interest,
        f.search_interest_7day_avg,
        f.percent_change_7day,
        f.trend_flag
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '7 days'
      AND f.percent_change_7day > 15  -- 15% increase threshold
      AND f.trend_flag = 'rising'
    ORDER BY f.percent_change_7day DESC, d.full_date DESC;
    """
    return run_query("Early Warning Indicators", query)

def main():
    """Run all analyses."""
    print("="*60)
    print("Influenza Surveillance Data Analysis")
    print("="*60)
    print(f"Database: {POSTGRES_URL.split('@')[1] if '@' in POSTGRES_URL else 'configured'}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # Run analyses
        df_states = analyze_state_comparison()
        df_trends = analyze_trends()
        df_time_series = analyze_time_series()
        df_dashboard = analyze_dashboard_metrics()
        df_warnings = analyze_early_warnings()
        
        # Create visualizations
        print("\n" + "="*60)
        print("Creating Visualizations...")
        print("="*60)
        create_visualizations(df_time_series)
        
        # Summary
        print("\n" + "="*60)
        print("Analysis Complete!")
        print("="*60)
        print("\nKey Insights:")
        if not df_states.empty:
            top_state = df_states.iloc[0]
            print(f"  • Highest average interest: {top_state['state_name']} ({top_state['avg_interest']:.2f})")
        if not df_trends.empty:
            rising_states = df_trends[df_trends['rising_days'] > df_trends['declining_days']]
            if not rising_states.empty:
                print(f"  • States with rising trends: {len(rising_states)}")
        if not df_warnings.empty:
            print(f"  • States with recent spikes: {len(df_warnings)}")
            for _, row in df_warnings.head(3).iterrows():
                print(f"    - {row['state_name']}: {row['percent_change_7day']:.1f}% increase")
        
        print("\nFiles created:")
        print("  • analysis_search_interest_timeseries.png")
        print("  • analysis_7day_average.png")
        
    except Exception as e:
        print(f"\n❌ Error running analysis: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
