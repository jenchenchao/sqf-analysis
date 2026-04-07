# ==============================================================================
# Try XGBoost for arrest prediction
# ==============================================================================
# Gradient boosted trees — typically strong on tabular data.
# Compare to random forest (CV log-loss: 0.192) from 05-ml-analysis.R.
# ==============================================================================

library(tidyverse)
library(xgboost)

source("R/ml_functions.R")

train <- read_rds("data/sqf_ml_train.rds")

# --- Reuse imputation and feature matrix from main script ---
train_medians <- list(
  age = median(train$age, na.rm = TRUE),
  height = median(train$height, na.rm = TRUE),
  weight = median(train$weight, na.rm = TRUE),
  xcoord = median(train$xcoord, na.rm = TRUE),
  ycoord = median(train$ycoord, na.rm = TRUE),
  month  = median(train$month, na.rm = TRUE),
  day_of_week = median(train$day_of_week, na.rm = TRUE)
)

impute_data <- function(data, medians = train_medians) {
  data %>% mutate(
    male = replace_na(male, FALSE),
    age = replace_na(age, medians$age),
    height = replace_na(height, medians$height),
    weight = replace_na(weight, medians$weight),
    build = fct_na_value_to_level(build, level = "missing"),
    location_type = fct_na_value_to_level(location_type, level = "missing"),
    officer_uniform = replace_na(officer_uniform, TRUE),
    hour = replace_na(hour, 12L),
    month = replace_na(month, medians$month),
    day_of_week = replace_na(day_of_week, medians$day_of_week),
    xcoord = replace_na(xcoord, medians$xcoord),
    ycoord = replace_na(ycoord, medians$ycoord)
  )
}

prepare_matrix <- function(data, medians = train_medians) {
  df <- impute_data(data, medians) %>%
    mutate(
      location_type_missing = is.na(data$location_type),
      xcoord_missing = is.na(data$xcoord),
      male_missing = is.na(data$male),
      build_missing = is.na(data$build),
      hour_bin = cut(hour, breaks = c(-1, 6, 12, 18, 24),
                     labels = c("night", "morning", "afternoon", "evening")),
      n_reasons = reason_object + reason_desc + reason_casing +
        reason_lookout + reason_clothing + reason_drugs +
        reason_furtive + reason_violent + reason_bulge + reason_other,
      n_circs = circ_report + circ_invest + circ_proximity +
        circ_evasive + circ_associate + circ_direction +
        circ_incident + circ_time + circ_sights + circ_other
    )
  pred_vars <- setdiff(names(df), c("id", "arrest"))
  f <- as.formula(paste("~", paste(pred_vars, collapse = " + ")))
  X <- model.matrix(f, data = df)[, -1]
  kept <- as.integer(rownames(X))
  list(X = X, kept_rows = kept)
}

cat("Preparing features...\n")
train_feat <- prepare_matrix(train)
X_train <- train_feat$X
y_train <- as.numeric(train$arrest[train_feat$kept_rows])
dtrain <- xgb.DMatrix(data = X_train, label = y_train)

cat("Feature matrix:", nrow(X_train), "x", ncol(X_train), "\n\n")


# --- XGBoost with 5-fold CV ---
cat("Running XGBoost 5-fold CV...\n")
set.seed(42)
xgb_cv <- xgb.cv(
  data = dtrain,
  params = list(
    objective = "binary:logistic",
    eval_metric = "logloss",
    eta = 0.1,
    max_depth = 6,
    subsample = 0.8,
    colsample_bytree = 0.8
  ),
  nrounds = 500,
  nfold = 5,
  early_stopping_rounds = 20,
  verbose = 0
)

xgb_log <- as_tibble(xgb_cv$evaluation_log)
best_round <- which.min(xgb_log$test_logloss_mean)
best_ll <- xgb_log$test_logloss_mean[best_round]

cat(sprintf("\nXGBoost CV log-loss: %.4f (best round: %d of %d)\n",
            best_ll, best_round, nrow(xgb_log)))
cat(sprintf("Train log-loss at best round: %.4f\n",
            xgb_log$train_logloss_mean[best_round]))

# --- Compare to other models ---
cat("\n--- Comparison ---\n")
cat("Baseline:            0.2245\n")
cat("Logistic regression: 0.2009\n")
cat("Lasso:               0.2000\n")
cat("Elastic net:         0.2000\n")
cat("Random forest:       0.1923\n")
cat(sprintf("XGBoost:             %.4f\n", best_ll))

# --- Training curve plot ---
p <- xgb_log %>%
  ggplot(aes(x = iter)) +
  geom_line(aes(y = train_logloss_mean, color = "Train")) +
  geom_line(aes(y = test_logloss_mean, color = "Validation")) +
  geom_vline(xintercept = best_round, linetype = "dashed") +
  labs(title = "XGBoost: Training Curve (5-fold CV)",
       x = "Boosting Rounds", y = "Log-Loss", color = NULL) +
  theme_minimal()
ggsave("output/xgb_training_curve.png", p, width = 7, height = 5, bg = "white")
cat("\nSaved output/xgb_training_curve.png\n")
