# 02-recode-data.R
# Recode raw SQF data into standardized, analysis-ready format.
# Uses helper functions from R/data_recoding.R to ensure consistency.

library(tidyverse)
library(lubridate)

source("R/data_loading.R")
source("R/data_recoding.R")

# Load raw data
sqf_raw <- read_rds("data/sqf_raw.rds")

message(sprintf("Loaded %s raw observations", format(nrow(sqf_raw), big.mark = ",")))

# Recode each year using recode_sqf_year()
# Split by year, apply recoding, combine results
sqf_clean <- sqf_raw %>%
  group_split(data_year) %>%
  map_dfr(~ recode_sqf_year(.x, unique(.x$data_year)))

# Print summary
message(sprintf("\nRecoded %s observations", format(nrow(sqf_clean), big.mark = ",")))
message("\nRows per year:")
print(count(sqf_clean, year, name = "n_stops"))

message("\nRace distribution:")
print(count(sqf_clean, race, name = "n") %>% mutate(pct = round(n / sum(n) * 100, 1)))

message(sprintf("\nAge: mean = %.1f, median = %d (%.1f%% NA)",
                mean(sqf_clean$age, na.rm = TRUE),
                median(sqf_clean$age, na.rm = TRUE),
                mean(is.na(sqf_clean$age)) * 100))

message(sprintf("Police force used: %.1f%%",
                mean(sqf_clean$police_force, na.rm = TRUE) * 100))

# Save cleaned data
output_path <- "data/sqf_clean.rds"
write_rds(sqf_clean, output_path, compress = "gz")
message(sprintf("\nCleaned data saved to: %s", output_path))
