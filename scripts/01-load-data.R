library(tidyverse)

# Load all years of SQF data using relative paths
years <- 2006:2012

sqf_all <- map_dfr(years, function(year) {
  file_path <- file.path("data", "raw", paste0(year, ".csv"))

  cat("Loading", file_path, "...\n")

  df <- read_csv(file_path, col_types = cols(.default = col_character()))
  df$year <- year
  df
})

# Print summary statistics for each year
sqf_all %>%
  group_by(year) %>%
  summarise(n_stops = n()) %>%
  print()
