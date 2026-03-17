# spatial_functions.R
# Helper functions for spatial analysis of SQF data.
# Handles Census tract download, coordinate conversion, spatial joins,
# aggregation, and choropleth mapping.

library(tidyverse)
library(sf)
library(tigris)

# Suppress tigris download messages and use cache
options(tigris_use_cache = TRUE)

# NYC standard CRS: State Plane, Long Island Zone (US survey feet)
NYC_CRS <- 2263


#' Download and prepare NYC Census tract boundaries
#'
#' Downloads tract shapefiles from the US Census Bureau via the tigris
#' package and standardizes column names. NYC spans five counties
#' (Manhattan=061, Brooklyn=047, Queens=081, Bronx=005, Staten Island=085).
#'
#' @param year Integer, Census year for tract boundaries (default: 2010)
#' @param crs Integer, EPSG code for coordinate reference system (default: 2263)
#' @return sf object with columns: ct_code, area_land, area_water, geometry
get_nyc_tracts <- function(year = 2010, crs = 2263) {
  nyc_counties <- c("061", "047", "081", "005", "085")

  message("Downloading Census tract boundaries for NYC...")

  tracts <- map(nyc_counties, function(county) {
    tracts(state = "NY", county = county, year = year, class = "sf")
  }) %>%
    bind_rows()

  # Select and rename columns (2010 Census uses GEOID10, ALAND10, AWATER10)
  tracts <- tracts %>%
    select(
      ct_code    = GEOID10,
      area_land  = ALAND10,
      area_water = AWATER10,
      geometry
    ) %>%
    st_transform(crs = crs)

  message(sprintf("Downloaded %d Census tracts for NYC", nrow(tracts)))

  return(tracts)
}


#' Convert SQF data to spatial points
#'
#' Takes a data frame with xcoord and ycoord columns and converts it
#' to an sf POINT object. Rows with missing coordinates are dropped.
#'
#' @param data Tibble with xcoord and ycoord columns
#' @param crs Integer, EPSG code matching the coordinate system (default: 2263)
#' @return sf object with POINT geometry
make_spatial <- function(data, crs = 2263) {
  # Validate required columns exist
  if (!all(c("xcoord", "ycoord") %in% names(data))) {
    stop("Data must contain 'xcoord' and 'ycoord' columns", call. = FALSE)
  }

  n_before <- nrow(data)

  # Drop rows with missing coordinates
  data_filtered <- data %>%
    filter(!is.na(xcoord), !is.na(ycoord))

  n_dropped <- n_before - nrow(data_filtered)
  message(sprintf("Dropped %s rows with missing coordinates (%.1f%%)",
                  format(n_dropped, big.mark = ","),
                  100 * n_dropped / n_before))

  # Convert to sf points
  data_sf <- st_as_sf(data_filtered,
                       coords = c("xcoord", "ycoord"),
                       crs = crs)

  message(sprintf("Created %s spatial points", format(nrow(data_sf), big.mark = ",")))

  return(data_sf)
}


#' Join spatial points to polygons
#'
#' Performs a spatial join to determine which polygon (e.g., Census tract)
#' each point falls within. Points that don't fall within any polygon
#' are dropped.
#'
#' @param points sf object with POINT geometry (e.g., SQF stops)
#' @param polygons sf object with POLYGON geometry (e.g., Census tracts)
#' @return sf object with point data joined to polygon attributes
spatial_join <- function(points, polygons) {
  # Validate inputs are sf objects
  if (!inherits(points, "sf")) {
    stop("`points` must be an sf object", call. = FALSE)
  }
  if (!inherits(polygons, "sf")) {
    stop("`polygons` must be an sf object", call. = FALSE)
  }

  # Check CRS match
  if (st_crs(points) != st_crs(polygons)) {
    stop(sprintf("CRS mismatch: points use %s, polygons use %s. Transform first.",
                 st_crs(points)$epsg, st_crs(polygons)$epsg),
         call. = FALSE)
  }

  message("Performing spatial join (this may take a moment)...")
  n_before <- nrow(points)

  # Spatial join: which tract does each point fall within?
  joined <- st_join(points, polygons, join = st_within)

  # Check for duplicates from join (points on tract boundaries)
  n_after_join <- nrow(joined)
  if (n_after_join > n_before) {
    n_dupes <- n_after_join - n_before
    warning(sprintf("Spatial join created %d duplicate rows (points on boundaries). Keeping first match.",
                    n_dupes))
    joined <- joined %>%
      group_by(id) %>%
      slice(1) %>%
      ungroup()
  }

  # Drop unmatched points (those outside all polygons)
  matched <- joined %>% filter(!is.na(ct_code))
  n_unmatched <- nrow(joined) - nrow(matched)

  message(sprintf("Matched: %s stops (%.1f%%)",
                  format(nrow(matched), big.mark = ","),
                  100 * nrow(matched) / n_before))
  message(sprintf("Unmatched (outside NYC): %s stops (%.1f%%)",
                  format(n_unmatched, big.mark = ","),
                  100 * n_unmatched / n_before))

  return(matched)
}


#' Aggregate SQF stops by Census tract
#'
#' Computes summary statistics for each Census tract from
#' geocoded stop-level data.
#'
#' @param geocoded_data sf object or tibble, geocoded SQF data (from spatial_join)
#' @return Tibble with one row per tract: ct_code, total_stops,
#'   stops_black, stops_hispanic, stops_white, pct_black, pct_force
aggregate_by_tract <- function(geocoded_data) {
  # Drop geometry for faster grouping if sf object
  if (inherits(geocoded_data, "sf")) {
    geocoded_data <- st_set_geometry(geocoded_data, NULL)
  }

  geocoded_data %>%
    group_by(ct_code) %>%
    summarize(
      total_stops    = n(),
      stops_black    = sum(race == "Black", na.rm = TRUE),
      stops_hispanic = sum(race == "Hispanic", na.rm = TRUE),
      stops_white    = sum(race == "White", na.rm = TRUE),
      pct_black      = round(100 * stops_black / total_stops, 1),
      pct_force      = round(100 * mean(police_force, na.rm = TRUE), 1),
      .groups = "drop"
    )
}


#' Create a choropleth map of SQF data by Census tract
#'
#' @param tract_data sf object with tract geometries and summary data
#' @param fill_var Character, name of the variable to map
#' @param title Character, plot title
#' @param log_scale Logical, whether to use log10 transform (default: FALSE)
#' @return ggplot object
map_tracts <- function(tract_data, fill_var, title = "", log_scale = FALSE) {
  p <- ggplot(tract_data) +
    geom_sf(aes(fill = .data[[fill_var]]),
            color = "white", linewidth = 0.05) +
    labs(title = title, fill = fill_var) +
    theme_void()

  if (log_scale) {
    p <- p + scale_fill_viridis_c(trans = "log10",
                                   labels = scales::comma,
                                   na.value = "grey90")
  } else {
    p <- p + scale_fill_viridis_c(na.value = "grey90")
  }

  return(p)
}
