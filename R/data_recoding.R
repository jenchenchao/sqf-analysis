# data_recoding.R
# Helper functions for recoding raw SQF data into standardized format.
# Each function encodes domain knowledge from the NYPD SQF codebook.

library(tidyverse)
library(lubridate)


#' Recode raw race codes to standardized categories
#'
#' Converts NYPD's single-letter race codes to full category names.
#' Based on NYPD Stop, Question and Frisk Database codebook.
#'
#' @param race_raw Character vector of raw race codes (W, B, P, Q, A, I, Z)
#' @return Factor with levels: White, Black, Hispanic, Asian, Other
#'
#' @details
#' Mapping:
#' - W = White
#' - B = Black
#' - P, Q = Hispanic
#' - A = Asian
#' - I, Z = Other
#' - Any other code = NA
#'
#' @examples
#' recode_race(c("W", "B", "P", "A"))
#' recode_race(c("Q", "X", "Z"))  # X becomes NA
recode_race <- function(race_raw) {
  recoded <- case_when(
    race_raw == "W" ~ "White",
    race_raw == "B" ~ "Black",
    race_raw %in% c("P", "Q") ~ "Hispanic",
    race_raw == "A" ~ "Asian",
    race_raw %in% c("I", "Z") ~ "Other",
    TRUE ~ NA_character_
  )

  factor(recoded, levels = c("White", "Black", "Hispanic", "Asian", "Other"))
}


#' Parse SQF date and time fields
#'
#' Parses separate date and time fields into Date and POSIXct columns.
#' Handles multiple date formats used across different years:
#' - 2006: "YYYY-MM-DD" (ymd format)
#' - 2007+: "MMDDYYYY" (mdy format)
#'
#' @param datestop Character vector of dates (various formats)
#' @param timestop Character/numeric vector of times (24-hour, variable padding)
#' @param date_format Character, format hint: "ymd" (2006) or "mdy" (2007+)
#' @return List with two elements: date (Date) and time (POSIXct)
#'
#' @details
#' Sentinel dates are treated as missing:
#' - "1900-12-31" (ymd format, 2006)
#' - "12311900" (mdy format, 2007+)
#'
#' @examples
#' parse_sqf_datetime("2006-01-15", "1430", "ymd")
#' parse_sqf_datetime("01152007", "830", "mdy")
parse_sqf_datetime <- function(datestop, timestop, date_format = "ymd") {
  # Replace sentinel dates with NA
  if (date_format == "ymd") {
    datestop <- na_if(datestop, "1900-12-31")
    parsed_date <- ymd(datestop, quiet = TRUE)
  } else {
    datestop <- na_if(datestop, "12311900")
    parsed_date <- mdy(datestop, quiet = TRUE)
  }

  # Pad timestop to 4 characters (e.g., "830" -> "0830")
  time_padded <- str_pad(timestop, width = 4, side = "left", pad = "0")

  # Combine date and time into datetime
  datetime_str <- paste(as.character(parsed_date), time_padded)
  parsed_time <- parse_date_time(datetime_str, orders = "Ymd HM", quiet = TRUE)

  list(date = parsed_date, time = parsed_time)
}


#' Clean age variable
#'
#' Converts age to integer and replaces invalid sentinel values with NA.
#' NYPD used various codes for missing/invalid age.
#'
#' @param age_raw Character or numeric vector of raw ages
#' @return Integer vector with invalid values as NA
#'
#' @details
#' Sentinel values replaced with NA:
#' - 99 (missing)
#' - 377 (invalid)
#' - 999 (unknown)
#' Values outside 0-100 are also set to NA.
#'
#' @examples
#' clean_age(c("25", "30", "99", "377"))
clean_age <- function(age_raw) {
  age_int <- as.integer(age_raw)

  # Replace known sentinel values
  age_int <- na_if(age_int, 999)
  age_int <- na_if(age_int, 377)

  # Replace implausible ages (>100 catches 99-as-missing and other outliers)
  age_int <- if_else(age_int < 0 | age_int > 100, NA_integer_, age_int)

  age_int
}


#' Recode raw SQF data to standardized format
#'
#' Transforms raw SQF data with inconsistent formatting into
#' a clean, standardized format. Uses helper functions to
#' ensure consistent recoding rules across all years.
#'
#' @param data_raw Tibble, raw SQF data from read_csv()
#' @param year Integer, year of the data (for ID generation and date parsing)
#' @return Tibble with standardized columns:
#'   id (character), date (Date), time (POSIXct), year (integer),
#'   race (factor), female (logical), age (integer),
#'   police_force (logical), precinct (integer), xcoord (numeric), ycoord (numeric)
#'
#' @examples
#' sqf_2006_raw <- load_sqf_year(2006)
#' sqf_2006_clean <- recode_sqf_year(sqf_2006_raw, 2006)
recode_sqf_year <- function(data_raw, year) {
  # Determine date format: 2006 uses ymd, 2007+ uses mdy
  date_fmt <- if (year == 2006) "ymd" else "mdy"

  # Parse date and time
  dt <- parse_sqf_datetime(data_raw$datestop, data_raw$timestop, date_fmt)

  # Identify police force columns (pf_*) present in the data
  pf_cols <- names(data_raw)[str_detect(names(data_raw), "^pf_")]

  # Compute police_force: TRUE if any pf_* column is "Y"
  force_matrix <- data_raw %>%
    select(all_of(pf_cols)) %>%
    mutate(across(everything(), ~ . == "Y"))
  police_force <- rowSums(force_matrix, na.rm = TRUE) > 0

  # Build standardized data frame
  tibble(
    id           = str_c(year, "-", seq_len(nrow(data_raw))),
    date         = dt$date,
    time         = dt$time,
    year         = as.integer(year),
    race         = recode_race(data_raw$race),
    female       = data_raw$sex == "F",
    age          = clean_age(data_raw$age),
    police_force = police_force,
    precinct     = as.integer(data_raw$pct),
    xcoord       = as.numeric(data_raw$xcoord),
    ycoord       = as.numeric(data_raw$ycoord)
  )
}
