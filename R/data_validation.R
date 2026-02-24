# data_validation.R
# Data validation functions for cleaned SQF data.
# Catches data quality issues early before they affect analysis.


#' Validate cleaned SQF data
#'
#' Performs comprehensive checks on cleaned SQF data to ensure
#' quality and catch potential data issues early.
#'
#' @param data Tibble, cleaned SQF data from recode_sqf_year()
#' @return List with validation results and any issues found
#'
#' @examples
#' sqf_clean <- read_rds("data/sqf_clean.rds")
#' validation <- validate_sqf_data(sqf_clean)
#' print(validation)
validate_sqf_data <- function(data) {
  issues <- list()

  # Check 1: Required columns exist
  required_cols <- c("id", "date", "time", "year", "race", "female",
                     "age", "police_force", "precinct", "xcoord", "ycoord")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    issues$missing_columns <- missing_cols
  }

  # Check 2: Year in valid range (2006-2012)
  invalid_years <- sum(data$year < 2006 | data$year > 2012, na.rm = TRUE)
  if (invalid_years > 0) {
    issues$invalid_years <- sprintf("%d rows with year outside 2006-2012", invalid_years)
  }

  # Check 3: Age in plausible range (0-100, allowing NA)
  invalid_ages <- sum(data$age < 0 | data$age > 100, na.rm = TRUE)
  if (invalid_ages > 0) {
    issues$invalid_ages <- sprintf("%d rows with age outside 0-100", invalid_ages)
  }
  age_na_pct <- round(mean(is.na(data$age)) * 100, 1)
  if (age_na_pct > 20) {
    issues$high_age_missing <- sprintf("%.1f%% of age values are NA", age_na_pct)
  }

  # Check 4: Race categories valid
  valid_levels <- c("White", "Black", "Hispanic", "Asian", "Other")
  if (is.factor(data$race)) {
    unexpected_levels <- setdiff(levels(data$race), valid_levels)
    if (length(unexpected_levels) > 0) {
      issues$unexpected_race_levels <- unexpected_levels
    }
  } else {
    issues$race_not_factor <- "race column should be a factor"
  }
  race_na_pct <- round(mean(is.na(data$race)) * 100, 1)
  if (race_na_pct > 5) {
    issues$high_race_missing <- sprintf("%.1f%% of race values are NA", race_na_pct)
  }

  # Check 5: Female is logical (TRUE/FALSE/NA only)
  if (!is.logical(data$female)) {
    issues$female_not_logical <- sprintf("female column is %s, expected logical",
                                         class(data$female)[1])
  }

  # Check 6: Coordinates present (should not be all NA)
  xcoord_na_pct <- round(mean(is.na(data$xcoord)) * 100, 1)
  ycoord_na_pct <- round(mean(is.na(data$ycoord)) * 100, 1)
  if (xcoord_na_pct > 50) {
    issues$high_xcoord_missing <- sprintf("%.1f%% of xcoord values are NA", xcoord_na_pct)
  }
  if (ycoord_na_pct > 50) {
    issues$high_ycoord_missing <- sprintf("%.1f%% of ycoord values are NA", ycoord_na_pct)
  }

  # Check 7: IDs are unique
  n_dupes <- nrow(data) - n_distinct(data$id)
  if (n_dupes > 0) {
    issues$duplicate_ids <- sprintf("%d duplicate IDs found", n_dupes)
  }

  # Return results
  list(
    passed   = length(issues) == 0,
    n_issues = length(issues),
    issues   = issues,
    n_rows   = nrow(data),
    n_cols   = ncol(data),
    year_counts = table(data$year)
  )
}
