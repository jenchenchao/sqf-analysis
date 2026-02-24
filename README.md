# NYC Stop and Frisk Analysis (2006-2012)

Analysis of NYPD Stop, Question, and Frisk data.

## Data Source

Data from [NYPD Stop, Question and Frisk Database](https://www1.nyc.gov/site/nypd/stats/reports-analysis/stopfrisk.page)

## Setup

1. Download 2006-2012 data files and place in `data/raw/`
2. Install required packages: `tidyverse`, `lubridate`
3. Run scripts in order (see Processing Pipeline below)

## Required Packages

- tidyverse
- lubridate

## Project Structure

```
sqf-analysis/
├── R/                          # Reusable functions
│   ├── data_loading.R          # load_sqf_year(), load_sqf_all()
│   ├── data_recoding.R         # recode_race(), parse_sqf_datetime(),
│   │                           # clean_age(), recode_sqf_year()
│   └── data_validation.R       # validate_sqf_data()
├── scripts/                    # Analysis scripts (run in order)
│   ├── 01-load-data.R          # Load raw CSVs, combine, save
│   ├── 02-recode-data.R        # Recode to standardized format
│   └── 03-validate-data.R      # Run validation checks
├── data/
│   ├── raw/                    # Raw CSV files (2006.csv - 2012.csv)
│   ├── sqf_raw.rds             # Combined raw data (from step 1)
│   └── sqf_clean.rds           # Cleaned data (from step 2)
├── output/
│   └── validation_report.rds   # Validation results (from step 3)
└── reference/                  # Assignment instructions (not tracked)
```

## Processing Pipeline

### Step 1: Load raw data (`scripts/01-load-data.R`)
- Loads all 7 years of CSV data using `load_sqf_year()` / `load_sqf_all()`
- All columns read as character to handle cross-year inconsistencies
- Saves combined raw data to `data/sqf_raw.rds`

### Step 2: Recode data (`scripts/02-recode-data.R`)
- Applies `recode_sqf_year()` to each year's data
- Uses helper functions for consistent recoding:
  - `recode_race()`: Maps NYPD single-letter codes (W, B, P, Q, A, I, Z) to standardized categories (White, Black, Hispanic, Asian, Other)
  - `parse_sqf_datetime()`: Handles date format differences (2006 uses ymd, 2007+ uses mdy) and sentinel dates
  - `clean_age()`: Converts to integer, replaces sentinel values (999, 377) and implausible ages (>100) with NA
- Computes `police_force` as TRUE if any `pf_*` column indicates force used
- Produces standardized columns: id, date, time, year, race, female, age, police_force, precinct, xcoord, ycoord
- Saves to `data/sqf_clean.rds`

### Step 3: Validate data (`scripts/03-validate-data.R`)
- Checks required columns exist
- Validates year range (2006-2012)
- Checks age plausibility (0-100)
- Verifies race factor levels
- Confirms female is logical type
- Checks coordinate missingness
- Verifies ID uniqueness
- Saves validation report to `output/validation_report.rds`
