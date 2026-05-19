# Influenza Surveillance ETL

An end-to-end data engineering pipeline for processing and analyzing influenza surveillance data from CDC FluView and HHS Hospital Utilization sources.

## Table of Contents

- [Problem Statement](#problem-statement)
- [Data Sources](#data-sources)
- [Architecture](#architecture)
- [Data Model](#data-model)
- [ETL Process](#etl-process)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Running the Pipeline Locally](#running-the-pipeline-locally)
- [Limitations and Tradeoffs](#limitations-and-tradeoffs)
- [Contributing](#contributing)
- [License](#license)

## Problem Statement

Influenza surveillance is critical for public health monitoring and early detection of outbreaks. This ETL pipeline automates the collection, transformation, and storage of influenza surveillance data from multiple sources, enabling timely analysis and reporting.

### Key Challenges Addressed

- **Data Integration**: Integrating data from disparate sources (CDC, HHS) with varying formats and update frequencies
- **Data Quality**: Ensuring data quality and consistency across multiple sources
- **Late-Arriving Data**: Handling data that arrives after initial processing windows
- **Schema Evolution**: Adapting to changes in source data schemas without breaking pipelines
- **Reliability**: Providing a reliable, automated data processing workflow with error handling and retries
- **Analytics-Ready Data**: Enabling downstream analytics and reporting with properly structured data models

## Data Sources

### CDC FluView

- **Source**: Centers for Disease Control and Prevention (CDC) FluView
- **API**: Delphi Epidata API (`https://api.delphi.cmu.edu/epidata/fluview/`)
- **Data Type**: Weekly influenza surveillance data
- **Update Frequency**: Weekly
- **Key Metrics**: 
  - Total specimens tested
  - Positive specimens
  - Percent positive
  - Geographic breakdown (national, HHS regions, states)
- **Format**: JSON via REST API

### HHS Hospital Utilization

- **Source**: U.S. Department of Health and Human Services (HHS)
- **Endpoint**: HealthData.gov (`https://healthdata.gov/resource/g62h-syeh.csv`)
- **Data Type**: Daily hospital capacity and utilization data
- **Update Frequency**: Daily
- **Key Metrics**:
  - Hospital admissions (adult, pediatric)
  - ICU bed usage and capacity
  - Inpatient bed utilization
  - Hospital capacity metrics
- **Format**: CSV via Socrata API

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         RAW DATA LAYER                           │
│  ┌──────────────┐              ┌──────────────┐                 │
│  │ CDC FluView  │              │ HHS Hospital │                 │
│  │     API      │              │ Utilization  │                 │
│  └──────┬───────┘              └──────┬───────┘                 │
│         │                              │                          │
│         └──────────────┬───────────────┘                          │
│                        ▼                                           │
│              ┌──────────────────┐                                 │
│              │  Raw File Store  │                                 │
│              │  (raw/YYYY/MM/DD)│                                 │
│              └────────┬─────────┘                                 │
└───────────────────────┼───────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                       STAGING LAYER                              │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │ staging.fluview_raw  │  │ staging.hhs_hosp_*   │            │
│  │                      │  │                      │            │
│  │ - Raw data storage   │  │ - Raw data storage   │            │
│  │ - Minimal transform  │  │ - Location normalize│            │
│  │ - Data validation    │  │ - Date normalize    │            │
│  └──────────┬───────────┘  └──────────┬───────────┘            │
└─────────────┼──────────────────────────┼────────────────────────┘
              │                          │
              └──────────┬───────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TRANSFORMATION LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Location Standardization │ Date Normalization          │  │
│  │  Schema Evolution         │ Late-Arriving Data Handling │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                        │
│                         ▼                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ANALYTICS LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Dimensions  │  │    Facts     │  │  Analytics   │        │
│  │              │  │              │  │              │        │
│  │ - dim_date   │  │ - Weekly     │  │ - Trends     │        │
│  │ - dim_location│ │   Cases      │  │ - Summaries  │        │
│  │ - dim_disease│ │ - Daily       │  │ - Indicators │        │
│  │ - dim_source │  │   Hospital   │  │              │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATION LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Apache Airflow DAGs                         │   │
│  │                                                          │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐       │   │
│  │  │  Ingest    │→ │ Transform  │→ │  Validate  │       │   │
│  │  │  CDC/HHS   │  │  to Facts  │  │  Quality   │       │   │
│  │  └────────────┘  └────────────┘  └────────────┘       │   │
│  │                                                          │   │
│  │  - Daily scheduling                                     │   │
│  │  - Retry logic                                          │   │
│  │  - Error notifications                                  │   │
│  │  - Backfill support                                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

### Architecture Flow

1. **Raw Data Layer**: 
   - External data sources (CDC FluView API, HHS CSV) are ingested
   - Raw files are stored in date-partitioned directories (`raw/YYYY/MM/DD/`)
   - Files preserved for audit and reprocessing

2. **Staging Layer**: 
   - Raw data is loaded into staging tables with minimal transformation
   - Data validation and quality checks are performed
   - Location and date normalization begins
   - Supports late-arriving data reprocessing

3. **Transformation Layer**:
   - Location codes standardized (state codes → FIPS codes)
   - Dates normalized to match CDC epiweek format
   - Schema changes handled gracefully
   - Rolling averages and trend calculations

4. **Analytics Layer**: 
   - Star schema design with dimension and fact tables
   - Dimension tables: date, location, disease, source
   - Fact tables: weekly cases, daily hospitalizations
   - Analytics tables for reporting and dashboards

5. **Orchestration Layer**: 
   - Apache Airflow DAGs coordinate the entire ETL process
   - Daily scheduling with retry logic
   - Error handling and notifications
   - Supports backfills for historical data

## Data Model

### Star Schema Design

The data warehouse uses a star schema design with dimension and fact tables for efficient querying and analysis.

### Dimension Tables

#### `dimensions.dim_date`
- **Purpose**: Time dimension for temporal analysis
- **Key Fields**: `date_id` (YYYYMMDD), `full_date`, `week_number`, `month`, `year`, `epiweek`, `flu_season`
- **Use Cases**: Time-based filtering, aggregations, trend analysis

#### `dimensions.dim_location`
- **Purpose**: Geographic dimension for location-based analysis
- **Key Fields**: `location_id`, `state_code`, `state_fips`, `region_code`, `location_type`
- **Use Cases**: Geographic filtering, regional comparisons, state-level analysis

#### `dimensions.dim_disease`
- **Purpose**: Disease classification for multi-disease surveillance
- **Key Fields**: `disease_id`, `disease_code`, `disease_name`, `disease_type`, `icd10_code`
- **Use Cases**: Disease filtering, multi-disease analysis, classification

#### `dimensions.dim_source`
- **Purpose**: Data source tracking and metadata
- **Key Fields**: `source_id`, `source_code`, `source_name`, `organization`, `update_frequency`
- **Use Cases**: Source attribution, data quality tracking, source-specific analysis

### Fact Tables

#### `facts.fact_flu_cases_weekly`
- **Grain**: One row per (date_id, location_id, disease_id, source_id) per week
- **Key Measures**:
  - `cases`, `positive_cases`, `total_tests`
  - `percent_positive`
  - `hospitalizations`, `deaths`
  - `cases_7day_avg`, `cases_30day_avg`
  - `trend_flag` (rising/stable/declining)
- **Foreign Keys**: References all dimension tables

#### `facts.fact_flu_hospitalizations_daily`
- **Grain**: One row per (date_id, location_id, disease_id, source_id) per day
- **Key Measures**:
  - `admissions`, `adult_admissions`, `pediatric_admissions`
  - `icu_patients`, `icu_adult_patients`
  - `total_beds`, `occupied_beds`, `bed_utilization_rate`
  - `total_icu_beds`, `occupied_icu_beds`, `icu_utilization_rate`
  - `admissions_7day_avg`, `admissions_30day_avg`
  - `trend_flag` (rising/stable/declining)
- **Foreign Keys**: References all dimension tables

### Staging Tables

- `staging.fluview_raw`: Raw CDC FluView data
- `staging.hhs_hospital_utilization_raw`: Raw HHS hospital utilization data
- `staging.flunet_raw`: Raw WHO FluNet data (optional)
- `staging.lab_results_raw`: Raw laboratory test results (optional)

## ETL Process

### 1. Extract

**CDC FluView Ingestion**:
- Fetches weekly influenza data from Delphi Epidata API
- Saves raw JSON and CSV files to date-partitioned directories
- Handles API rate limiting and errors gracefully

**HHS Hospital Utilization Ingestion**:
- Downloads CSV data from HealthData.gov
- Processes multiple days (configurable lookback) for late-arriving data
- Saves raw files with metadata

### 2. Transform

**Location Standardization**:
- Converts state abbreviations to FIPS codes
- Normalizes region codes (HHS, Census, CDC)
- Handles missing or invalid location codes

**Date Normalization**:
- Converts various date formats to standardized datetime
- Calculates CDC epiweek format (YYYYWW)
- Handles week boundaries and year transitions

**Data Cleaning**:
- Handles missing values appropriately
- Validates data ranges and types
- Flags data quality issues

**Calculations**:
- Computes 7-day and 30-day rolling averages
- Calculates trend flags based on 2-week change
- Computes utilization rates and percentages

### 3. Load

**Staging Load**:
- Loads raw data into staging tables
- Preserves original data for audit
- Supports schema evolution

**Fact Table Load**:
- Incremental upsert to prevent duplicates
- Handles late-arriving data updates
- Maintains referential integrity with dimensions

**Data Quality Validation**:
- Checks for null values in key columns
- Validates no duplicate records
- Verifies date ranges match source data
- Checks incremental load integrity

### 4. Orchestration

**Airflow DAG Workflow**:
1. Ingest CDC FluView data (daily)
2. Ingest HHS hospital data (daily)
3. Transform CDC staging to facts
4. Transform HHS staging to facts
5. Calculate rolling averages and trends
6. Validate data quality

**Features**:
- Daily scheduling at midnight
- 3 retries with exponential backoff
- Failure notifications via logging
- Backfill support for historical dates
- Task dependencies ensure proper execution order

## Project Structure

```
.
├── src/                          # Python ETL scripts
│   ├── extract/                  # Data extraction modules
│   │   ├── cdc_extractor.py
│   │   └── who_extractor.py
│   ├── transform/                # Data transformation modules
│   │   └── data_cleaner.py
│   ├── load/                     # Data loading modules
│   │   └── database_loader.py
│   ├── ingest_cdc_fluview.py     # CDC FluView ingestion script
│   ├── ingest_hhs_hospital_utilization.py  # HHS ingestion script
│   └── validate_data_quality.py  # Data quality validation
│
├── dags/                         # Apache Airflow DAGs
│   ├── influenza_surveillance_etl_dag.py  # Main ETL DAG
│   └── README.md
│
├── sql/                          # SQL warehouse models
│   ├── dimensions/               # Dimension tables (star schema)
│   │   ├── create_dimension_tables.sql
│   │   └── seed_dimension_data.sql
│   ├── facts/                    # Fact tables
│   │   ├── create_fact_tables.sql
│   │   └── incremental_load_procedures.sql
│   ├── transform/                # Transformation scripts
│   │   ├── utilities.sql
│   │   ├── transform_cdc_fluview_to_facts.sql
│   │   ├── transform_hhs_to_facts.sql
│   │   └── calculate_rolling_averages_and_trends.sql
│   ├── validation/               # Data quality validation
│   │   ├── data_quality_checks.sql
│   │   └── validation_functions.sql
│   ├── staging/                  # Staging table definitions
│   │   └── create_staging_tables.sql
│   └── analytics/                   # Analytics tables
│       └── create_analytics_tables.sql
│
├── raw/                          # Raw data storage (date-partitioned)
│   ├── YYYY/
│   │   └── MM/
│   │       └── DD/
│
├── logs/                         # Log files
│
├── requirements.txt              # Python dependencies
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Getting Started

### Prerequisites

- **Python**: 3.8 or higher
- **PostgreSQL**: 12+ (or BigQuery for cloud deployment)
- **Apache Airflow**: 2.0+ (optional, for orchestration)
- **Git**: For cloning the repository

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd "Disease Trends"
   ```

2. **Create a virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**:
   ```bash
   # Database connection
   export POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
   
   # Optional: Warehouse selection
   export WAREHOUSE=postgres  # or 'bigquery'
   
   # Optional: Data directories
   export RAW_DATA_DIR=raw
   export LOG_DIR=logs
   ```

5. **Initialize database schemas**:
   ```bash
   # Create schemas
   psql -d influenza_db -f sql/dimensions/create_schema.sql
   psql -d influenza_db -f sql/facts/create_schema.sql
   psql -d influenza_db -f sql/transform/create_schema.sql
   psql -d influenza_db -f sql/validation/create_schema.sql
   
   # Create tables
   psql -d influenza_db -f sql/dimensions/create_dimension_tables.sql
   psql -d influenza_db -f sql/facts/create_fact_tables.sql
   psql -d influenza_db -f sql/staging/create_staging_tables.sql
   
   # Seed dimension data
   psql -d influenza_db -f sql/dimensions/seed_dimension_data.sql
   
   # Create transformation functions
   psql -d influenza_db -f sql/transform/utilities.sql
   psql -d influenza_db -f sql/transform/transform_cdc_fluview_to_facts.sql
   psql -d influenza_db -f sql/transform/transform_hhs_to_facts.sql
   psql -d influenza_db -f sql/transform/calculate_rolling_averages_and_trends.sql
   psql -d influenza_db -f sql/transform/orchestrate_transformations.sql
   
   # Create validation functions
   psql -d influenza_db -f sql/validation/validation_functions.sql
   ```

## Running the Pipeline Locally

### Option 1: Standalone Scripts (Recommended for Testing)

#### Run CDC FluView Ingestion

```bash
# Set environment variables
export POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
export STAGING_SCHEMA=staging
export STAGING_TABLE=fluview_raw

# Run ingestion
python src/ingest_cdc_fluview.py
```

#### Run HHS Hospital Utilization Ingestion

```bash
# Set environment variables
export POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
export STAGING_SCHEMA=staging
export HHS_STAGING_TABLE=hhs_hospital_utilization_raw
export HHS_LOOKBACK_DAYS=7

# Run ingestion
python src/ingest_hhs_hospital_utilization.py
```

#### Run Transformations

```bash
# Connect to database and run transformation functions
psql -d influenza_db -c "SELECT * FROM transform.load_cdc_fluview_to_facts();"
psql -d influenza_db -c "SELECT * FROM transform.load_hhs_to_facts();"
psql -d influenza_db -c "SELECT * FROM transform.update_rolling_averages_weekly();"
psql -d influenza_db -c "SELECT * FROM transform.update_trend_flags_weekly();"
```

#### Run Data Quality Validation

```bash
# Python script
python src/validate_data_quality.py

# Or SQL functions
psql -d influenza_db -c "SELECT * FROM validation.run_all_checks();"
```

### Option 2: Airflow Orchestration (Recommended for Production)

1. **Set up Airflow**:
   ```bash
   # Initialize Airflow database
   airflow db init
   
   # Create Airflow user
   airflow users create \
     --username admin \
     --firstname Admin \
     --lastname User \
     --role Admin \
     --email admin@example.com
   ```

2. **Configure Airflow**:
   - Set `AIRFLOW_HOME` environment variable
   - Update `airflow.cfg` with database connection
   - Set environment variables for DAG execution

3. **Start Airflow services**:
   ```bash
   # Start scheduler
   airflow scheduler
   
   # Start webserver (in another terminal)
   airflow webserver --port 8080
   ```

4. **Deploy DAG**:
   - Copy `dags/influenza_surveillance_etl_dag.py` to Airflow DAGs folder
   - DAG should appear in Airflow UI at `http://localhost:8080`

5. **Trigger DAG**:
   - Use Airflow UI to trigger manually
   - Or use CLI: `airflow dags trigger influenza_surveillance_etl`

6. **Backfill Historical Data**:
   ```bash
   airflow dags backfill influenza_surveillance_etl \
     --start-date 2024-01-01 \
     --end-date 2024-01-31
   ```

### Option 3: Complete Pipeline Run

Run all steps in sequence:

```bash
# 1. Ingest data
python src/ingest_cdc_fluview.py
python src/ingest_hhs_hospital_utilization.py

# 2. Transform to facts
psql -d influenza_db -c "SELECT * FROM transform.run_all_transformations();"

# 3. Validate data quality
python src/validate_data_quality.py
```

### Verifying the Pipeline

1. **Check staging tables**:
   ```sql
   SELECT COUNT(*) FROM staging.fluview_raw;
   SELECT COUNT(*) FROM staging.hhs_hospital_utilization_raw;
   ```

2. **Check fact tables**:
   ```sql
   SELECT COUNT(*) FROM facts.fact_flu_cases_weekly;
   SELECT COUNT(*) FROM facts.fact_flu_hospitalizations_daily;
   ```

3. **Run sample queries**:
   ```sql
   -- Weekly cases by state
   SELECT 
       l.state_name,
       d.week_number,
       f.cases,
       f.positive_cases,
       f.percent_positive
   FROM facts.fact_flu_cases_weekly f
   JOIN dimensions.dim_date d ON f.date_id = d.date_id
   JOIN dimensions.dim_location l ON f.location_id = l.location_id
   WHERE d.year = 2024
   ORDER BY l.state_name, d.week_number;
   ```

## Limitations and Tradeoffs

### Limitations

1. **Data Source Dependencies**:
   - Pipeline depends on external APIs (CDC, HHS) being available
   - API rate limits may affect ingestion speed
   - Schema changes in source data require pipeline updates

2. **Data Latency**:
   - CDC FluView data is updated weekly (not real-time)
   - HHS data may have 1-2 day delay
   - Late-arriving data requires reprocessing

3. **Geographic Coverage**:
   - Currently focused on US data (CDC, HHS)
   - International data (WHO FluNet) is optional
   - State-level granularity may vary by source

4. **Data Completeness**:
   - Some metrics may be missing for certain dates/locations
   - Historical data may have gaps
   - Data quality varies by source and time period

5. **Scalability**:
   - Designed for moderate data volumes
   - Large-scale deployments may require optimization
   - BigQuery support available but requires GCP setup

### Tradeoffs

1. **Schema Evolution vs. Performance**:
   - **Choice**: Automatic schema evolution (adds columns, never drops)
   - **Tradeoff**: Tables may accumulate unused columns over time
   - **Benefit**: Handles source schema changes without breaking pipelines

2. **Idempotency vs. Performance**:
   - **Choice**: Delete existing records before insert (upsert pattern)
   - **Tradeoff**: Slightly slower than direct inserts
   - **Benefit**: Safe to rerun without creating duplicates

3. **Data Freshness vs. Resource Usage**:
   - **Choice**: Process multiple days for late-arriving data
   - **Tradeoff**: Increased processing time and resource usage
   - **Benefit**: Captures late-arriving data automatically

4. **Comprehensive Validation vs. Speed**:
   - **Choice**: Extensive data quality checks
   - **Tradeoff**: Additional processing time
   - **Benefit**: Higher confidence in data quality

5. **Modularity vs. Complexity**:
   - **Choice**: Separate scripts for each data source
   - **Tradeoff**: More files to maintain
   - **Benefit**: Easier to debug and extend

### Known Issues

- HHS data may contain COVID-19 data mixed with flu data (requires filtering)
- CDC epiweek calculation may differ slightly from official CDC calculations
- Some location codes may not map perfectly between sources
- Date normalization handles most cases but edge cases may require manual intervention

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

1. Install development dependencies:
   ```bash
   pip install -r requirements.txt
   pip install pytest pytest-cov black flake8
   ```

2. Run tests (when available):
   ```bash
   pytest tests/
   ```

3. Format code:
   ```bash
   black src/ dags/
   ```

## License

MIT License - see LICENSE file for details

## Acknowledgments

- CDC FluView for providing influenza surveillance data
- HHS for providing hospital utilization data
- Delphi Epidata API for CDC FluView API access
- Apache Airflow community for orchestration framework

## Support

For issues, questions, or contributions, please open an issue on the repository.

---

**Last Updated**: 2024
