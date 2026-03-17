# NYC Stop and Frisk Analysis (2006-2012)

Analysis of NYPD Stop, Question, and Frisk data from 2006 to 2012, the peak years of the program. This project loads, cleans, validates, geocodes, and maps SQF records using a modular, reproducible pipeline.

## Data Source

Data from the [NYPD Stop, Question and Frisk Database](https://www1.nyc.gov/site/nypd/stats/reports-analysis/stopfrisk.page). Each row represents one police stop and includes information on the date, time, location, demographics of the person stopped, reason for the stop, and whether force was used.

The raw data files cover 2006-2012 (approximately 500,000+ stops per year at peak) and are provided as CSV files with inconsistent formatting across years.

## Setup

1. Clone this repository
2. Download 2006-2012 SQF data files from the NYPD website and place them in `data/raw/` as `2006.csv`, `2007.csv`, ..., `2012.csv`
3. Install required packages:
   ```r
   install.packages(c("tidyverse", "lubridate", "sf", "tigris"))
   ```
4. Run scripts in order from the project root directory (see Processing Pipeline below):
   ```r
   source("scripts/01-load-data.R")
   source("scripts/02-recode-data.R")
   source("scripts/03-validate-data.R")
   source("scripts/04-geocode-data.R")
   ```

## Required Packages

- `tidyverse` (dplyr, readr, stringr, purrr, tidyr, ggplot2, forcats)
- `lubridate` (date/time parsing)
- `sf` (spatial data: points, polygons, spatial joins)
- `tigris` (download Census boundary shapefiles from the US Census Bureau)

## Project Structure

```
sqf-analysis/
├── R/                          # Reusable functions
│   ├── data_loading.R          # load_sqf_year(), load_sqf_all()
│   ├── data_recoding.R         # recode_race(), parse_sqf_datetime(),
│   │                           # clean_age(), recode_sqf_year()
│   ├── data_validation.R       # validate_sqf_data()
│   └── spatial_functions.R     # get_nyc_tracts(), make_spatial(),
│                               # spatial_join(), aggregate_by_tract(), map_tracts()
├── scripts/                    # Analysis scripts (run in order)
│   ├── 01-load-data.R          # Load raw CSVs, combine, save
│   ├── 02-recode-data.R        # Recode to standardized format
│   ├── 03-validate-data.R      # Run validation checks
│   └── 04-geocode-data.R       # Spatial join, aggregation, mapping
├── data/
│   ├── raw/                    # Raw CSV files (2006.csv - 2012.csv)
│   ├── sqf_raw.rds             # Combined raw data (from step 1)
│   ├── sqf_clean.rds           # Cleaned data (from step 2)
│   ├── sqf_geocoded.rds        # Geocoded data with tract IDs (from step 4)
│   └── nyc_tracts.rds          # NYC Census tract boundaries (from step 4)
├── output/
│   ├── validation_report.rds   # Validation results (from step 3)
│   ├── map_total_stops.png     # Choropleth: total stops by tract
│   └── map_pct_black.png       # Choropleth: % Black stops by tract
└── reference/                  # Assignment instructions, slides (not tracked)
```

**Design principles:**
- **Separation of concerns**: Reusable functions live in `R/`; scripts that orchestrate them live in `scripts/`. This keeps logic modular and testable.
- **DRY (Don't Repeat Yourself)**: Instead of copy-pasting recoding logic 7 times (once per year), we wrote reusable functions that are called once per year via `map_dfr()`.
- **Relative paths**: All file paths use `file.path()` relative to the project root, so the code works on any machine.

## Processing Pipeline

### Step 1: Load raw data (`scripts/01-load-data.R`)

Loads all 7 years of CSV data and combines them into a single data frame.

- Uses `load_sqf_year()` to read each year's CSV with all columns as **character type** to avoid type-guessing issues across years (e.g., the same column may be numeric in one year and character in another)
- Uses `load_sqf_all()` to iterate over years via `purrr::map_dfr()` and row-bind results
- Input validation: checks that year is numeric, in range 2006-2012, and that the file exists before reading
- Adds a `data_year` column to track the source year
- Saves combined raw data to `data/sqf_raw.rds` (compressed with gzip)

### Step 2: Recode data (`scripts/02-recode-data.R`)

Transforms raw data into a standardized, analysis-ready format using helper functions that encode domain knowledge from the NYPD codebook.

**Helper functions** (in `R/data_recoding.R`):

| Function | Purpose | Key decisions |
|----------|---------|---------------|
| `recode_race()` | Maps NYPD single-letter codes to standardized categories | W=White, B=Black, P/Q=Hispanic, A=Asian, I/Z=Other; invalid codes become NA; returns ordered factor |
| `parse_sqf_datetime()` | Parses date and time fields into Date/POSIXct | 2006 uses `ymd` format, 2007+ uses `mdy`; sentinel dates (1900-12-31) replaced with NA; time zero-padded to 4 digits |
| `clean_age()` | Converts age to integer, removes sentinels | 999 (unknown), 377 (invalid) set to NA; ages outside 0-100 set to NA |

**Main function** `recode_sqf_year()`:
- Calls helper functions to produce a standardized tibble with columns: `id`, `date`, `time`, `year`, `race`, `female`, `age`, `police_force`, `precinct`, `xcoord`, `ycoord`
- Computes `police_force` as TRUE if any `pf_*` column equals "Y"
- Generates unique IDs in format "YYYY-rownum"
- Processes all years via `group_split(data_year) %>% map_dfr()`
- Saves cleaned data to `data/sqf_clean.rds`

### Step 3: Validate data (`scripts/03-validate-data.R`)

Runs comprehensive validation checks to catch data quality issues before they silently affect analysis.

**Validation checks** (in `R/data_validation.R`):

| Check | What it validates | Threshold |
|-------|-------------------|-----------|
| Required columns | All 11 expected columns present | Any missing = issue |
| Year range | All years between 2006-2012 | Any out of range = issue |
| Age plausibility | Ages within 0-100 | Any invalid = issue; >20% NA = warning |
| Race categories | Factor with expected levels only | Unexpected levels = issue; >5% NA = warning |
| Female type | Column is logical (TRUE/FALSE) | Wrong type = issue |
| Coordinate missingness | xcoord/ycoord not mostly missing | >50% NA = warning |
| ID uniqueness | No duplicate IDs | Any duplicates = issue |

Returns a list with `passed` (logical), `n_issues` (count), `issues` (named list of problems), and summary statistics (`n_rows`, `n_cols`, `year_counts`).

## Output Variables

The cleaned dataset (`data/sqf_clean.rds`) contains the following columns:

| Variable | Type | Description |
|----------|------|-------------|
| `id` | character | Unique stop identifier (format: "YYYY-rownum") |
| `date` | Date | Date of the stop |
| `time` | POSIXct | Date-time of the stop |
| `year` | integer | Year of the stop (2006-2012) |
| `race` | factor | Race/ethnicity (White, Black, Hispanic, Asian, Other) |
| `female` | logical | TRUE if female, FALSE if male |
| `age` | integer | Age of person stopped (NA if missing/implausible) |
| `police_force` | logical | TRUE if any physical force was used |
| `precinct` | integer | NYPD precinct number |
| `xcoord` | numeric | X coordinate (State Plane) |
| `ycoord` | numeric | Y coordinate (State Plane) |

## Key Design Decisions

1. **All columns loaded as character**: Raw CSVs have inconsistent types across years. Loading everything as character prevents silent coercion errors; explicit type conversion happens during recoding.

2. **Sentinel values replaced with NA**: The NYPD data uses various codes for missing data (999, 377 for age; 1900-12-31 for date). These are replaced with `NA` rather than left as misleading numeric values.

3. **Race coding**: Hispanic is coded as two separate values (P = Black-Hispanic, Q = White-Hispanic) in the raw data. Both are mapped to "Hispanic" following standard practice in SQF research.

4. **Police force**: Derived from multiple `pf_*` columns (hands, wall, ground, draw weapon, point weapon, baton, pepper spray, other). Any "Y" across these columns flags the stop as involving force.

5. **Validation as a separate step**: Validation runs after recoding (not during) so that issues are reported comprehensively rather than failing on the first problem. This makes debugging easier.

### Step 4: Geocode and map (`scripts/04-geocode-data.R`)

Links each SQF stop to a Census tract via spatial join and produces choropleth maps.

**Coordinate Reference System:** The SQF data uses EPSG 2263 (NY State Plane, Long Island Zone), a projected CRS measured in US survey feet optimized for the NYC area. All spatial operations use this CRS to ensure accurate distances and proper alignment between stop coordinates and Census tract boundaries.

**Helper functions** (in `R/spatial_functions.R`):

| Function | Purpose | Key decisions |
|----------|---------|---------------|
| `get_nyc_tracts()` | Downloads Census tract boundaries for all five NYC counties | Uses `tigris::tracts()` for each borough; projects to EPSG 2263; retains only ct_code, area_land, area_water |
| `make_spatial()` | Converts data frame to sf POINT object | Drops rows with missing xcoord/ycoord; reports how many dropped; uses `st_as_sf()` |
| `spatial_join()` | Joins points to polygons via `st_within` | Validates CRS match; handles boundary duplicates; reports matched vs. unmatched counts |
| `aggregate_by_tract()` | Computes tract-level summary statistics | Total stops, stops by race, % Black, % force; drops geometry for speed |
| `map_tracts()` | Creates choropleth map with `geom_sf()` | Optional log scale for skewed data; viridis color palette; `theme_void()` |

**Pipeline steps:**
1. Downloads Census tract boundaries for NYC (5 boroughs, 2010 vintage)
2. Converts SQF stops to spatial points (drops missing coordinates)
3. Spatial join assigns each stop to its Census tract
4. Validates: checks for empty tracts, duplicate rows from join
5. Aggregates by tract (all years combined) and by tract-year (using `map()`)
6. Creates two choropleth maps: total stops (log scale) and % Black stops
7. Saves geocoded data to `data/sqf_geocoded.rds`, tracts to `data/nyc_tracts.rds`, maps to `output/`
