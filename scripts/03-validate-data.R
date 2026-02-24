# 03-validate-data.R
# Run validation checks on cleaned SQF data.

library(tidyverse)

source("R/data_validation.R")

# Load cleaned data
sqf_clean <- read_rds("data/sqf_clean.rds")

# Run validation
validation <- validate_sqf_data(sqf_clean)

# Print results
message("\n=== Data Validation Report ===\n")
message(sprintf("Rows: %s", format(validation$n_rows, big.mark = ",")))
message(sprintf("Columns: %d", validation$n_cols))

message("\nRows per year:")
print(validation$year_counts)

if (validation$passed) {
  message("\nAll validation checks passed!")
} else {
  message(sprintf("\nFound %d issue(s):\n", validation$n_issues))
  for (name in names(validation$issues)) {
    issue <- validation$issues[[name]]
    message(sprintf("  - %s: %s", name, toString(issue)))
  }
}

# Save validation report
write_rds(validation, "output/validation_report.rds")
message("\nValidation report saved to: output/validation_report.rds")
