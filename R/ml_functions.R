# ml_functions.R
# Helper functions for ML assignment: evaluation metrics and cross-validation.


#' Compute classification accuracy
#'
#' @param actual Logical or 0/1 vector of true outcomes
#' @param predicted_prob Numeric vector of predicted probabilities
#' @param threshold Numeric, classification threshold (default 0.5)
#' @return Numeric, proportion correctly classified
#'
#' @examples
#' compute_accuracy(c(TRUE, FALSE, TRUE), c(0.8, 0.3, 0.6))
#' compute_accuracy(c(1, 0, 1, 0), c(0.9, 0.1, 0.4, 0.6), threshold = 0.5)
compute_accuracy <- function(actual, predicted_prob, threshold = 0.5) {
  stopifnot(
    "actual and predicted_prob must have same length" =
      length(actual) == length(predicted_prob),
    "predicted_prob must be between 0 and 1" =
      all(predicted_prob >= 0 & predicted_prob <= 1, na.rm = TRUE)
  )
  predicted_class <- predicted_prob >= threshold
  mean(as.logical(actual) == predicted_class)
}


#' Compute log-loss (binary cross-entropy)
#'
#' Evaluates predicted probabilities directly. Lower is better.
#' Probabilities are clipped to [eps, 1-eps] to avoid log(0).
#'
#' @param actual Logical or 0/1 vector of true outcomes
#' @param predicted_prob Numeric vector of predicted probabilities
#' @param eps Numeric, clipping bound (default 1e-15)
#' @return Numeric, log-loss value
#'
#' @examples
#' compute_logloss(c(TRUE, FALSE, TRUE), c(0.9, 0.1, 0.8))
#' compute_logloss(c(1, 0), c(0.5, 0.5))  # should be ~0.693
compute_logloss <- function(actual, predicted_prob, eps = 1e-15) {
  stopifnot(
    "actual and predicted_prob must have same length" =
      length(actual) == length(predicted_prob),
    "predicted_prob must be between 0 and 1" =
      all(predicted_prob >= 0 & predicted_prob <= 1, na.rm = TRUE)
  )
  y <- as.numeric(actual)
  p <- pmin(pmax(predicted_prob, eps), 1 - eps)
  -mean(y * log(p) + (1 - y) * log(1 - p))
}


#' Evaluate model with both accuracy and log-loss
#'
#' @param actual Logical or 0/1 vector of true outcomes
#' @param predicted_prob Numeric vector of predicted probabilities
#' @return Named numeric vector with accuracy and logloss
#'
#' @examples
#' evaluate_model(c(TRUE, FALSE), c(0.8, 0.2))
evaluate_model <- function(actual, predicted_prob) {
  c(accuracy = compute_accuracy(actual, predicted_prob),
    logloss  = compute_logloss(actual, predicted_prob))
}


#' Compute baseline metrics (majority-class predictor)
#'
#' Baseline: predict the overall event rate for every observation.
#' Any useful model must beat this.
#'
#' @param y Logical or 0/1 vector of true outcomes
#' @return Named numeric vector with baseline accuracy and logloss
#'
#' @examples
#' baseline_metrics(c(rep(TRUE, 6), rep(FALSE, 94)))
baseline_metrics <- function(y) {
  p <- mean(as.numeric(y))
  # Accuracy: predict majority class
  acc <- max(p, 1 - p)
  # Log-loss: predict p for everyone
  ll <- compute_logloss(y, rep(p, length(y)))
  c(accuracy = acc, logloss = ll, base_rate = p)
}


#' K-fold cross-validation for glm models
#'
#' Reusable CV function following lecture pattern (modelr::crossv_kfold).
#' Returns log-loss for each fold plus mean and SD.
#'
#' @param formula Formula for glm
#' @param data Data frame
#' @param k Integer, number of folds (default 5)
#' @param seed Integer, random seed for reproducibility
#' @return List with fold_results (tibble), mean_logloss, sd_logloss
#'
#' @examples
#' # cv_logloss(arrest ~ age + male, data = train, k = 5)
cv_logloss <- function(formula, data, k = 5, seed = 42) {
  library(modelr)

  set.seed(seed)
  folds <- crossv_kfold(data, k = k)

  fold_results <- tibble(
    fold = 1:k,
    logloss = map_dbl(1:k, function(i) {
      train_data <- as.data.frame(folds$train[[i]])
      test_data  <- as.data.frame(folds$test[[i]])

      fit <- glm(formula, family = binomial, data = train_data)
      preds <- predict(fit, newdata = test_data, type = "response")

      compute_logloss(test_data[[as.character(formula[[2]])]], preds)
    })
  )

  list(
    fold_results = fold_results,
    mean_logloss = mean(fold_results$logloss),
    sd_logloss   = sd(fold_results$logloss)
  )
}
