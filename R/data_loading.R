#' Load SQF data for a specific year
#'
#' Loads a single year of Stop, Question, and Frisk data from CSV file.
#' All columns are loaded as character type to handle inconsistencies.
#'
#' @param year Integer, the year to load (must be between 2006 and 2012)
#' @param data_dir Character, path to directory containing CSV files
#' @return Tibble with SQF data for the specified year, includes data_year column
#'
#' @examples
#' sqf_2006 <- load_sqf_year(2006)
#' sqf_2010 <- load_sqf_year(2010, data_dir = "data/raw")
load_sqf_year <- function(year, data_dir = "data/raw") {
  # Input validation
  stopifnot(
    "Year must be numeric" = is.numeric(year),
    "Year must be a single value" = length(year) == 1,
    "Year must be between 2006 and 2012" = year >= 2006 & year <= 2012,
    "Data directory must be a character string" = is.character(data_dir)
  )

  # Construct file path
  file_name <- paste0(year, ".csv")
  file_path <- file.path(data_dir, file_name)

  if (!file.exists(file_path)) {
    stop(sprintf("File not found: %s\nPlease ensure the file exists in %s",
                 file_name, data_dir))
  }

  message(sprintf("Loading data for year %d...", year))

  # Load CSV with all columns as character to avoid type guessing issues
  data <- read_csv(
    file_path,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )

  # Add year column for identification after combining
  data <- data %>%
    mutate(data_year = as.integer(year))

  return(data)
}


#' Load and combine SQF data for multiple years
#'
#' Loads SQF data for multiple years and combines them into a single data frame.
#'
#' @param years Integer vector, years to load (each must be 2006-2012)
#' @param data_dir Character, path to directory containing CSV files
#' @return Tibble with combined SQF data from all specified years
#'
#' @examples
#' sqf_all <- load_sqf_all()
#' sqf_subset <- load_sqf_all(years = c(2010, 2011, 2012))
load_sqf_all <- function(years = 2006:2012, data_dir = "data/raw") {
  stopifnot(
    "Years must be numeric" = is.numeric(years),
    "Years must be between 2006 and 2012" = all(years >= 2006 & years <= 2012)
  )

  message(sprintf("Loading %d years of SQF data...", length(years)))

  sqf_data <- map_dfr(years, load_sqf_year, data_dir = data_dir)

  message(sprintf("Successfully loaded %s rows from %d years",
                  format(nrow(sqf_data), big.mark = ","),
                  length(years)))

  return(sqf_data)
}
