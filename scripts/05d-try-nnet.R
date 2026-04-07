# ==============================================================================
# Try Neural Network for arrest prediction
# ==============================================================================
# Single hidden layer neural network via nnet.
# Compare to XGBoost (0.188) and random forest (0.192).
# ==============================================================================

library(tidyverse)
library(nnet)
library(modelr)

source("R/ml_functions.R")

train <- read_rds("data/sqf_ml_train.rds")

# --- Imputation ---
train_medians <- list(
  age = median(train$age, na.rm = TRUE),
  height = median(train$height, na.rm = TRUE),
  weight = median(train$weight, na.rm = TRUE),
  xcoord = median(train$xcoord, na.rm = TRUE),
  ycoord = median(train$ycoord, na.rm = TRUE),
  month  = median(train$month, na.rm = TRUE),
  day_of_week = median(train$day_of_week, na.rm = TRUE)
)

train_imputed <- train %>% mutate(
  male = replace_na(male, FALSE),
  age = replace_na(age, train_medians$age),
  height = replace_na(height, train_medians$height),
  weight = replace_na(weight, train_medians$weight),
  build = fct_na_value_to_level(build, level = "missing"),
  location_type = fct_na_value_to_level(location_type, level = "missing"),
  officer_uniform = replace_na(officer_uniform, TRUE),
  hour = replace_na(hour, 12L),
  month = replace_na(month, train_medians$month),
  day_of_week = replace_na(day_of_week, train_medians$day_of_week),
  xcoord = replace_na(xcoord, train_medians$xcoord),
  ycoord = replace_na(ycoord, train_medians$ycoord)
)

# Scale numeric features (important for neural networks)
numeric_cols <- names(train_imputed)[map_lgl(train_imputed, is.numeric)]
numeric_cols <- setdiff(numeric_cols, "id")

train_scaled <- train_imputed %>%
  mutate(across(all_of(numeric_cols), ~ scale(.)[, 1]))

cat("Data prepared:", nrow(train_scaled), "rows\n\n")


# --- 5-fold CV for nnet ---
cat("Running neural network 5-fold CV...\n")
set.seed(42)
folds <- crossv_kfold(train_scaled, k = 5)

nn_cv_ll <- map_dbl(1:5, function(i) {
  cat(sprintf("  Fold %d...\n", i))
  tr <- as.data.frame(folds$train[[i]])
  te <- as.data.frame(folds$test[[i]])
  nn <- nnet(
    arrest ~ . - id,
    data = tr, size = 10, maxit = 200, decay = 0.01,
    linout = FALSE, trace = FALSE
  )
  preds <- predict(nn, newdata = te, type = "raw")[, 1]
  ll <- compute_logloss(te$arrest, preds)
  cat(sprintf("    log-loss: %.4f\n", ll))
  ll
})

nn_ll <- mean(nn_cv_ll)
cat(sprintf("\nNeural network CV log-loss: %.4f (SD: %.4f)\n", nn_ll, sd(nn_cv_ll)))

# --- Compare to other models ---
cat("\n--- Final Comparison ---\n")
cat("Baseline:            0.2245\n")
cat("Logistic regression: 0.2009\n")
cat("Lasso:               0.2000\n")
cat("Elastic net:         0.2000\n")
cat("Random forest:       0.1923\n")
cat("XGBoost:             0.1881\n")
cat(sprintf("Neural network:      %.4f\n", nn_ll))
cat(sprintf("\nBest model: %s\n",
            ifelse(nn_ll < 0.1881, "Neural network", "XGBoost")))
