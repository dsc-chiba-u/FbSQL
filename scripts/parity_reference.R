# Reference values from stats::glm() for the pg_regress fixtures.
#
# The data below is kept literally in sync with the fixtures in test/sql/.
# Run inside the fbsql-dev container (or any R >= 4):
#     Rscript scripts/parity_reference.R
# and compare the printed tables against test/expected/*.out.
# Rounding (4 decimals) matches the test queries.

t_gaussian <- data.frame(
    y  = c(-0.3, 1.9, 1.3, 5.7, 3.5, 7.6, 7.3, 11.7, 10.9, 15.6, 11.7, 17.1),
    x1 = c(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
    x2 = c(5, 3, 8, 1, 9, 4, 7, 2, 6, 0, 10, 3)
)

t_binomial <- data.frame(
    y = c(0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0),
    x = c(0.1, 0.4, 0.8, 1.0, 1.2, 1.5, 1.8, 2.0, 2.2, 2.5, 2.8, 3.0)
)

t_factor <- data.frame(
    y      = c(1.0, 2.0, 1.5, 2.5, 3.0, 2.8),
    gender = c("F", "M", "F", "M", "Other", "Other")
)

# The 12 complete rows of t_gaussian plus 3 rows containing NULL/NA
# (test/sql/fit_glm_nulls.sql); glm()'s na.omit must drop exactly those 3.
t_nulls <- rbind(
    t_gaussian,
    data.frame(y = c(NA, 99.9, 50.0), x1 = c(12, NA, 13), x2 = c(4, 2, NA))
)

reference_table <- function(data, formula, family_name) {
    fam <- switch(family_name,
                  gaussian = stats::gaussian(),
                  binomial = stats::binomial())
    fit <- stats::glm(formula, data = data, family = fam)
    coefs <- summary(fit)$coefficients
    ci <- stats::confint.default(fit)  # Wald, as in fbsql.fit_glm()
    out <- data.frame(
        term          = rownames(coefs),
        estimate      = round(coefs[, 1], 4),
        std_error     = round(coefs[, 2], 4),
        statistic     = round(coefs[, 3], 4),
        p_value       = round(coefs[, 4], 4),
        conf_low_95   = round(ci[, 1], 4),
        conf_high_95  = round(ci[, 2], 4),
        family        = family_name,
        link          = fam$link,
        formula       = deparse(formula),
        n_obs         = nrow(data),
        n_used        = stats::nobs(fit),
        n_dropped     = nrow(data) - stats::nobs(fit),
        aic           = round(stats::AIC(fit), 4),
        deviance      = round(stats::deviance(fit), 4),
        null_deviance = round(fit$null.deviance, 4),
        row.names     = NULL
    )
    out[order(out$term), ]
}

cat("== t_gaussian: y ~ x1 + x2, gaussian ==\n")
print(reference_table(t_gaussian, y ~ x1 + x2, "gaussian"), width = 200)

cat("\n== t_gaussian: y ~ x1, gaussian (family default) ==\n")
print(reference_table(t_gaussian, y ~ x1, "gaussian")[, c("term", "estimate")])

cat("\n== t_binomial: y ~ x, binomial ==\n")
print(reference_table(t_binomial, y ~ x, "binomial"), width = 200)

cat("\n== t_factor: y ~ gender, gaussian ==\n")
print(reference_table(t_factor, y ~ gender, "gaussian"), width = 200)

cat("\n== t_nulls: y ~ x1 + x2, gaussian (Complete Case Analysis) ==\n")
print(reference_table(t_nulls, y ~ x1 + x2, "gaussian")[,
    c("term", "estimate", "std_error", "n_obs", "n_used", "n_dropped")])

# ---- predict_glm() stage 1 reference (test/sql/predict_glm_numeric.sql) ----
t_train <- data.frame(
    y = c(1.0, 2.0, 3.0, 4.0, 5.0),
    x = c(0.0, 1.0, 2.0, 3.0, 4.0)
)
t_new <- data.frame(id = c(1L, 2L, 3L), x = c(1.5, 3.5, NA))

cat("\n== predict: y ~ x on t_new (NA row must predict NA) ==\n")
fit_p <- stats::glm(y ~ x, data = t_train, family = stats::gaussian())
print(cbind(t_new,
            y_predicted = round(stats::predict(fit_p, newdata = t_new), 4)))
