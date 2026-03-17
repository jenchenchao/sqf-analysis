# 04-geocode-data.R
# Geocode SQF stops by assigning each to a Census tract via spatial join.
# Then aggregate by tract and create choropleth maps.

library(tidyverse)
library(sf)
library(tigris)

source("R/spatial_functions.R")

# =============================================================================
# Part 1: Geocoding Pipeline
# =============================================================================

# Load cleaned data (from Assignment 2)
sqf_clean <- read_rds("data/sqf_clean.rds")
message(sprintf("Loaded %s cleaned stops", format(nrow(sqf_clean), big.mark = ",")))

# Step 1: Download Census tract boundaries
tracts <- get_nyc_tracts()

# Step 2: Convert SQF data to spatial points
sqf_spatial <- make_spatial(sqf_clean)

# Step 3: Spatial join -- assign each stop to a Census tract
sqf_geocoded <- spatial_join(sqf_spatial, tracts)

# Summary
message(sprintf(
  "\nGeocoded %s of %s stops (%.1f%%)",
  format(nrow(sqf_geocoded), big.mark = ","),
  format(nrow(sqf_clean), big.mark = ","),
  100 * nrow(sqf_geocoded) / nrow(sqf_clean)
))

# =============================================================================
# Part 2: Validation
# =============================================================================

message("\n=== Geocoding Validation ===\n")

# Check 1: Are there tracts with zero stops?
tract_counts <- sqf_geocoded %>%
  st_set_geometry(NULL) %>%
  count(ct_code)
n_empty_tracts <- nrow(tracts) - n_distinct(tract_counts$ct_code)
message(sprintf("Census tracts with zero stops: %d of %d (%.1f%%)",
                n_empty_tracts, nrow(tracts),
                100 * n_empty_tracts / nrow(tracts)))

# Check 2: Any duplicate rows from spatial join?
n_dupes <- nrow(sqf_geocoded) - n_distinct(sqf_geocoded$id)
if (n_dupes > 0) {
  message(sprintf("WARNING: %d duplicate stop IDs after spatial join", n_dupes))
} else {
  message("No duplicate stop IDs -- spatial join is clean")
}

# Save geocoded data and tracts
write_rds(sqf_geocoded, "data/sqf_geocoded.rds", compress = "gz")
write_rds(tracts, "data/nyc_tracts.rds", compress = "gz")
message("\nSaved: data/sqf_geocoded.rds, data/nyc_tracts.rds")

# =============================================================================
# Part 3: Aggregation
# =============================================================================

# Aggregate across all years
tract_summary <- aggregate_by_tract(sqf_geocoded)

# Aggregate by year using map() -- applies the same function to each year's data
# This follows the Week 5 pattern: write a function, test on one case, map across all
tract_by_year <- sqf_geocoded %>%
  st_set_geometry(NULL) %>%
  group_split(year) %>%
  map(aggregate_by_tract) %>%
  bind_rows()

message(sprintf("\nAggregated to %d tract summaries (all years combined)",
                nrow(tract_summary)))
message(sprintf("Aggregated to %d tract-year summaries", nrow(tract_by_year)))

# =============================================================================
# Part 4: Maps
# =============================================================================

# Join tract summaries to geometries for mapping
tract_map_data <- tracts %>%
  left_join(tract_summary, by = "ct_code")

# --- Map 1: Total stops by Census tract (log scale for skewed counts) ---
p1 <- map_tracts(tract_map_data, "total_stops",
                 title = "Total SQF Stops by Census Tract (2006-2012)",
                 log_scale = TRUE)

ggsave("output/map_total_stops.png", p1,
       width = 8, height = 8, dpi = 300, bg = "white")
message("Saved: output/map_total_stops.png")

# --- Map 2: Percent of stops involving Black civilians ---
p2 <- map_tracts(tract_map_data, "pct_black",
                 title = "Percent of SQF Stops Involving Black Civilians (2006-2012)")

ggsave("output/map_pct_black.png", p2,
       width = 8, height = 8, dpi = 300, bg = "white")
message("Saved: output/map_pct_black.png")

message("\n=== Assignment 4 pipeline complete ===")
