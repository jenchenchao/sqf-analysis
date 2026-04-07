# ==============================================================================
# Validate Your ML Submission (for students)
# ==============================================================================
# Run this script to check that your holdout_predictions.csv is
# formatted correctly before submitting.
#
# Usage: source("scripts/validate-submission.R")
# ==============================================================================

library(tidyverse)

SUBMISSION_PATH <- "output/holdout_predictions.csv"
HOLDOUT_PATH    <- "data/sqf_ml_holdout.rds"

# --- Check file exists -------------------------------------------------------
if (!file.exists(SUBMISSION_PATH)) {
  stop(
    "File not found: ", SUBMISSION_PATH,
    "\nMake sure you saved your predictions there."
  )
}

# --- Read submission ----------------------------------------------------------
sub <- read_csv(SUBMISSION_PATH, show_col_types = FALSE)
cat("Read", nrow(sub), "rows from", SUBMISSION_PATH, "\n\n")

# --- Check columns ------------------------------------------------------------
required_cols <- c("id", "predicted_probability")
missing_cols  <- setdiff(required_cols, names(sub))
if (length(missing_cols) > 0) {
  stop(
    "Missing required columns: ",
    paste(missing_cols, collapse = ", "),
    "\nYour CSV must have columns: id, predicted_probability"
  )
}
cat("[PASS] Required columns present\n")

# --- Check against holdout IDs ------------------------------------------------
holdout <- read_rds(HOLDOUT_PATH)

if (nrow(sub) != nrow(holdout)) {
  cat(
    "[WARN] Row count mismatch: your submission has",
    nrow(sub), "rows, holdout has", nrow(holdout), "\n"
  )
} else {
  cat("[PASS] Row count matches holdout (", nrow(sub), ")\n")
}

missing_ids <- setdiff(holdout$id, sub$id)
extra_ids   <- setdiff(sub$id, holdout$id)

if (length(missing_ids) > 0) {
  cat(
    "[FAIL] Missing", length(missing_ids),
    "holdout IDs in your submission\n"
  )
} else {
  cat("[PASS] All holdout IDs present\n")
}

if (length(extra_ids) > 0) {
  cat("[WARN] Your submission has", length(extra_ids), "extra IDs\n")
}

# --- Check predicted_probability values ---------------------------------------
probs <- sub$predicted_probability

if (any(is.na(probs))) {
  cat("[FAIL]", sum(is.na(probs)), "NA values in predicted_probability\n")
} else {
  cat("[PASS] No NA values\n")
}

if (any(probs < 0 | probs > 1, na.rm = TRUE)) {
  n_bad <- sum(probs < 0 | probs > 1, na.rm = TRUE)
  cat(
    "[FAIL]", n_bad,
    "values outside [0, 1] range\n"
  )
} else {
  cat("[PASS] All values in [0, 1] range\n")
}

# --- Summary ------------------------------------------------------------------
cat(
  "\n--- Prediction summary ---\n",
  sprintf("  Min:    %.4f\n", min(probs, na.rm = TRUE)),
  sprintf("  Median: %.4f\n", median(probs, na.rm = TRUE)),
  sprintf("  Mean:   %.4f\n", mean(probs, na.rm = TRUE)),
  sprintf("  Max:    %.4f\n", max(probs, na.rm = TRUE)),
  sprintf(
    "  Predicted arrests (p > 0.5): %d (%.1f%%)\n",
    sum(probs > 0.5, na.rm = TRUE),
    100 * mean(probs > 0.5, na.rm = TRUE)
  )
)

all_pass <- length(missing_cols) == 0 &&
  length(missing_ids) == 0 &&
  !any(is.na(probs)) &&
  !any(probs < 0 | probs > 1, na.rm = TRUE)

if (all_pass) {
  cat("\nAll checks passed. Ready to submit!\n")
} else {
  cat("\nSome checks failed. Fix the issues above.\n")
}
