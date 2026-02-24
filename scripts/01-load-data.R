# 01-load-data.R
# Load raw SQF data for all years (2006-2012) and save combined file.

library(tidyverse)

# Source custom loading functions
source("R/data_loading.R")

# Load all years of SQF data
sqf_raw <- load_sqf_all(years = 2006:2012, data_dir = "data/raw")

# Print summary statistics
message("\n=== Data Summary ===")
message(sprintf("Total rows: %s", format(nrow(sqf_raw), big.mark = ",")))
message(sprintf("Total columns: %d", ncol(sqf_raw)))

# Rows per year
year_summary <- sqf_raw %>%
  group_by(data_year) %>%
  summarise(n_stops = n(), .groups = "drop") %>%
  arrange(data_year)

print(year_summary)

# Save combined raw data
output_path <- "data/sqf_raw.rds"
write_rds(sqf_raw, output_path, compress = "gz")
message(sprintf("\nData saved to: %s", output_path))
