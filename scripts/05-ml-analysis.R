# ==============================================================================
# Assignment 5: Predicting Stop Outcomes with Machine Learning
# ==============================================================================
# Predicts whether a police stop results in an arrest using SQF data.
# Competition metric: log-loss (lower is better).
# ==============================================================================

library(tidyverse)
library(glmnet)
library(modelr)
library(ranger)

source("R/ml_functions.R")


# ==============================================================================
# SECTION 1: Exploration and Preparation
# ==============================================================================

train   <- read_rds("data/sqf_ml_train.rds")
holdout <- read_rds("data/sqf_ml_holdout.rds")

cat("=== Training data ===\n")
cat("Dimensions:", dim(train), "\n")
cat("Arrest rate:", round(mean(train$arrest), 4), "\n\n")

cat("=== Holdout data ===\n")
cat("Dimensions:", dim(holdout), "\n\n")

# Outcome distribution
cat("Arrest counts:\n")
print(table(train$arrest))
cat("\n")

# Missing values
na_counts <- colSums(is.na(train))
cat("Variables with missing values:\n")
print(na_counts[na_counts > 0])
cat("\n")

# Arrest rates by key predictors
cat("Arrest rate by crime_suspected:\n")
train %>%
  group_by(crime_suspected) %>%
  summarize(n = n(), arrest_rate = mean(arrest), .groups = "drop") %>%
  arrange(desc(arrest_rate)) %>%
  print()

cat("\nArrest rate by race:\n")
train %>%
  group_by(race) %>%
  summarize(n = n(), arrest_rate = mean(arrest), .groups = "drop") %>%
  print()

# Reason flags: which are most associated with arrest?
reason_cols <- names(train)[str_detect(names(train), "^reason_")]
cat("\nArrest rate by stop reason:\n")
map_dfr(reason_cols, function(col) {
  tibble(
    reason = col,
    arrest_rate_if_true  = mean(train$arrest[train[[col]] == TRUE]),
    arrest_rate_if_false = mean(train$arrest[train[[col]] == FALSE])
  )
}) %>%
  mutate(diff = arrest_rate_if_true - arrest_rate_if_false) %>%
  arrange(desc(abs(diff))) %>%
  print()


# ==============================================================================
# SECTION 2: Evaluation Infrastructure
# ==============================================================================

cat("\n=== Evaluation Infrastructure ===\n")

# Majority-class baseline
baseline <- baseline_metrics(train$arrest)
cat("Baseline (always predict arrest rate):\n")
cat(sprintf("  Accuracy: %.4f\n", baseline["accuracy"]))
cat(sprintf("  Log-loss: %.4f\n", baseline["logloss"]))
cat(sprintf("  Base rate: %.4f\n", baseline["base_rate"]))

# Sanity checks
cat("\nSanity check — perfect predictions:\n")
print(evaluate_model(c(TRUE, FALSE, TRUE, FALSE), c(1, 0, 1, 0)))
cat("Random predictions:\n")
print(evaluate_model(c(TRUE, FALSE, TRUE, FALSE), c(0.5, 0.5, 0.5, 0.5)))


# ==============================================================================
# SECTION 3: Baseline Model and Overfitting
# ==============================================================================

cat("\n=== Baseline Model & Overfitting ===\n")

# Impute NAs for modeling
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

train_imputed <- impute_data(train)

# Train/validation split (70/30) — lecture pattern
set.seed(1235)
train_set      <- sample_frac(train_imputed, 0.7)
validation_set <- anti_join(train_imputed, train_set, by = "id")

cat("Training set:  ", nrow(train_set), "rows\n")
cat("Validation set:", nrow(validation_set), "rows\n\n")

# --- Model 1: Simple logistic regression (few predictors) ---
m1 <- glm(arrest ~ age + male + race, family = binomial, data = train_set)

m1_in  <- evaluate_model(train_set$arrest, predict(m1, type = "response"))
m1_out <- evaluate_model(validation_set$arrest,
                          predict(m1, newdata = validation_set, type = "response"))

cat("Model 1 (simple: age + male + race):\n")
cat(sprintf("  In-sample  — accuracy: %.4f, log-loss: %.4f\n", m1_in[1], m1_in[2]))
cat(sprintf("  Out-sample — accuracy: %.4f, log-loss: %.4f\n", m1_out[1], m1_out[2]))

# --- Model 2: More predictors ---
m2 <- glm(arrest ~ age + male + race + crime_suspected +
             reason_desc + reason_casing + reason_furtive + reason_bulge +
             reason_drugs + reason_violent + reason_other +
             inside + radio_run + officer_uniform,
           family = binomial, data = train_set)

m2_in  <- evaluate_model(train_set$arrest, predict(m2, type = "response"))
m2_out <- evaluate_model(validation_set$arrest,
                          predict(m2, newdata = validation_set, type = "response"))

cat("\nModel 2 (more predictors):\n")
cat(sprintf("  In-sample  — accuracy: %.4f, log-loss: %.4f\n", m2_in[1], m2_in[2]))
cat(sprintf("  Out-sample — accuracy: %.4f, log-loss: %.4f\n", m2_out[1], m2_out[2]))

# --- Model 3: Add interactions to show overfitting ---
m3 <- glm(arrest ~ (age + male + race + crime_suspected +
             reason_desc + reason_furtive + reason_bulge +
             reason_drugs + reason_violent) * race,
           family = binomial, data = train_set)

m3_in  <- evaluate_model(train_set$arrest, predict(m3, type = "response"))
m3_out <- evaluate_model(validation_set$arrest,
                          predict(m3, newdata = validation_set, type = "response"))

cat("\nModel 3 (with interactions — more complex):\n")
cat(sprintf("  In-sample  — accuracy: %.4f, log-loss: %.4f\n", m3_in[1], m3_in[2]))
cat(sprintf("  Out-sample — accuracy: %.4f, log-loss: %.4f\n", m3_out[1], m3_out[2]))

# Compare
cat("\n--- Summary: In-sample vs. Out-of-sample ---\n")
comparison <- tibble(
  model = c("Baseline", "M1: simple", "M2: more predictors", "M3: interactions"),
  insample_logloss  = c(baseline["logloss"], m1_in[2], m2_in[2], m3_in[2]),
  outsample_logloss = c(baseline["logloss"], m1_out[2], m2_out[2], m3_out[2]),
  gap = insample_logloss - outsample_logloss
)
print(comparison)
# More complexity = better in-sample but gap grows = overfitting pattern


# ==============================================================================
# SECTION 4: Cross-Validation
# ==============================================================================

cat("\n=== Cross-Validation ===\n")

cv_m2 <- cv_logloss(
  arrest ~ age + male + race + crime_suspected +
    reason_desc + reason_casing + reason_furtive + reason_bulge +
    reason_drugs + reason_violent + reason_other +
    inside + radio_run + officer_uniform,
  data = train_imputed, k = 5
)

cat("5-fold CV results for Model 2:\n")
print(cv_m2$fold_results)
cat(sprintf("\nCV mean log-loss: %.4f (SD: %.4f)\n",
            cv_m2$mean_logloss, cv_m2$sd_logloss))
cat(sprintf("Single split estimate: %.4f\n", m2_out[2]))
cat("CV provides a more robust estimate by averaging over 5 splits.\n")


# ==============================================================================
# SECTION 5: Improve Predictions
# ==============================================================================

cat("\n=== Part B: Improving Predictions ===\n")

# --- Feature matrix for glmnet ---
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

cat("Preparing feature matrix...\n")
train_feat <- prepare_matrix(train)
X_train <- train_feat$X
y_train <- as.numeric(train$arrest[train_feat$kept_rows])
cat("Feature matrix:", nrow(X_train), "x", ncol(X_train), "\n")

all_results <- list()


# --- Spec 1: Logistic regression (all main effects) ---
cat("\n--- Spec 1: Logistic regression (all main effects) ---\n")
cv_glm <- cv_logloss(
  arrest ~ age + male + race + crime_suspected + build +
    height + weight + precinct + inside + location_type +
    radio_run + officer_uniform + year + month + day_of_week + hour +
    reason_object + reason_desc + reason_casing + reason_lookout +
    reason_clothing + reason_drugs + reason_furtive + reason_violent +
    reason_bulge + reason_other +
    circ_report + circ_invest + circ_proximity + circ_evasive +
    circ_associate + circ_direction + circ_incident + circ_time +
    circ_sights + circ_other,
  data = train_imputed, k = 5
)
cat(sprintf("CV log-loss: %.4f (SD: %.4f)\n", cv_glm$mean_logloss, cv_glm$sd_logloss))
all_results[["Logistic regression"]] <- cv_glm$mean_logloss


# --- Spec 2: Lasso logistic regression ---
cat("\n--- Spec 2: Lasso logistic regression ---\n")
set.seed(42)
cv_lasso <- cv.glmnet(
  x = X_train, y = y_train,
  family = "binomial", type.measure = "deviance",
  alpha = 1, nfolds = 5
)
lasso_ll <- min(cv_lasso$cvm) / 2
cat(sprintf("CV log-loss: %.4f\n", lasso_ll))
cat(sprintf("  lambda.min: %.6f | Non-zero coefs: %d\n",
            cv_lasso$lambda.min, sum(coef(cv_lasso, s = "lambda.min") != 0)))
all_results[["Lasso"]] <- lasso_ll

# Save lasso lambda path plot
png("output/lasso_lambda_path.png", width = 800, height = 500, bg = "white")
plot(cv_lasso, main = "Lasso: CV Deviance across Lambda Values")
dev.off()


# --- Spec 3: Elastic net (grid search over alpha) ---
cat("\n--- Spec 3: Elastic net (alpha grid search) ---\n")
alpha_grid <- c(0, 0.25, 0.5, 0.75, 1.0)

enet_results <- tibble(alpha = alpha_grid) %>%
  mutate(
    cv_fit = map(alpha, function(a) {
      set.seed(42)
      cv.glmnet(x = X_train, y = y_train,
                 family = "binomial", type.measure = "deviance",
                 alpha = a, nfolds = 5)
    }),
    logloss = map_dbl(cv_fit, ~ min(.x$cvm) / 2),
    lambda_min = map_dbl(cv_fit, ~ .x$lambda.min)
  )

cat("Alpha grid results:\n")
enet_results %>% select(alpha, logloss, lambda_min) %>% print()

best_enet_idx <- which.min(enet_results$logloss)
best_enet_ll  <- enet_results$logloss[best_enet_idx]
cat(sprintf("Best alpha: %.2f (CV log-loss: %.4f)\n",
            enet_results$alpha[best_enet_idx], best_enet_ll))
all_results[["Elastic net"]] <- best_enet_ll

# Alpha comparison plot
p_alpha <- enet_results %>%
  ggplot(aes(x = factor(alpha), y = logloss)) +
  geom_point(size = 3) + geom_line(aes(group = 1)) +
  labs(title = "Elastic Net: CV Log-Loss across Alpha",
       x = "Alpha (0 = Ridge, 1 = Lasso)", y = "CV Log-Loss") +
  theme_minimal()
ggsave("output/alpha_comparison.png", p_alpha, width = 7, height = 5, bg = "white")


# --- Spec 4: Random forest ---
# Random forest can capture nonlinear relationships and interactions
# that linear models miss, without requiring explicit specification.
cat("\n--- Spec 4: Random forest ---\n")
set.seed(42)
folds_rf <- crossv_kfold(train_imputed, k = 5)

rf_cv_ll <- map_dbl(1:5, function(i) {
  tr <- as.data.frame(folds_rf$train[[i]]) %>%
    mutate(arrest_f = factor(arrest, levels = c(FALSE, TRUE)))
  te <- as.data.frame(folds_rf$test[[i]]) %>%
    mutate(arrest_f = factor(arrest, levels = c(FALSE, TRUE)))
  rf <- ranger(arrest_f ~ . - id - arrest, data = tr,
               num.trees = 500, probability = TRUE,
               min.node.size = 20, mtry = 6, seed = 42)
  preds <- predict(rf, data = te)$predictions[, "TRUE"]
  compute_logloss(te$arrest, preds)
})
rf_ll <- mean(rf_cv_ll)
cat(sprintf("CV log-loss: %.4f (SD: %.4f)\n", rf_ll, sd(rf_cv_ll)))
all_results[["Random forest"]] <- rf_ll


# --- Final comparison ---
cat("\n========================================\n")
cat("   MODEL COMPARISON (CV Log-Loss)\n")
cat("========================================\n")
model_comparison <- tibble(
  specification = c("Baseline", names(all_results)),
  cv_logloss = c(as.numeric(baseline["logloss"]), as.numeric(unlist(all_results)))
) %>% arrange(cv_logloss)
print(model_comparison, n = 10)

best_model_name <- model_comparison$specification[1]
cat(sprintf("\nBest model: %s (CV log-loss: %.4f)\n",
            best_model_name, model_comparison$cv_logloss[1]))

# Model comparison plot
p_compare <- model_comparison %>%
  mutate(specification = fct_reorder(specification, cv_logloss)) %>%
  ggplot(aes(x = specification, y = cv_logloss)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = as.numeric(baseline["logloss"]),
             linetype = "dashed", color = "red") +
  coord_flip() +
  labs(title = "Model Comparison: CV Log-Loss",
       x = NULL, y = "CV Log-Loss (lower is better)",
       caption = "Red line = baseline (predict overall arrest rate)") +
  theme_minimal()
ggsave("output/model_comparison.png", p_compare, width = 8, height = 4, bg = "white")


# ==============================================================================
# SECTION 6: Competition Submission
# ==============================================================================

cat("\n=== Generating Holdout Predictions ===\n")

# Refit random forest on full training data
cat("Fitting random forest on full training data...\n")
train_rf <- train_imputed %>%
  mutate(arrest_f = factor(arrest, levels = c(FALSE, TRUE)))

rf_final <- ranger(
  arrest_f ~ . - id - arrest,
  data = train_rf, num.trees = 500, probability = TRUE,
  min.node.size = 20, mtry = 6, seed = 42
)

holdout_imp <- impute_data(holdout) %>%
  mutate(arrest_f = factor(FALSE, levels = c(FALSE, TRUE)))

holdout_preds <- predict(rf_final, data = holdout_imp)$predictions[, "TRUE"]

submission <- tibble(
  id = holdout$id,
  predicted_probability = holdout_preds
)

cat(sprintf("Predictions: min=%.4f median=%.4f mean=%.4f max=%.4f\n",
            min(holdout_preds), median(holdout_preds),
            mean(holdout_preds), max(holdout_preds)))

write_csv(submission, "output/holdout_predictions.csv")
cat("Saved output/holdout_predictions.csv\n")


# ==============================================================================
# Validate submission
# ==============================================================================

cat("\n=== Running validation ===\n")
source("scripts/validate-submission.R")

cat("\n=== Done! ===\n")
