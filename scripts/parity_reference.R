# Reference values from stats::glm() for the pg_regress fixtures.
#
# The data below is kept literally in sync with test/sql/fit_glm_gaussian.sql.
# Run inside the fbsql-dev container (or any R >= 4):
#     Rscript scripts/parity_reference.R
# and compare the printed tables against test/expected/fit_glm_gaussian.out.
# Rounding (4 decimals) matches the test queries.

t_gaussian <- data.frame(
    y  = c(-0.3, 1.9, 1.3, 5.7, 3.5, 7.6, 7.3, 11.7, 10.9, 15.6, 11.7, 17.1),
    x1 = c(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
    x2 = c(5, 3, 8, 1, 9, 4, 7, 2, 6, 0, 10, 3)
)

reference_table <- function(fit, formula_string) {
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
        family        = "gaussian",
        link          = "identity",
        formula       = formula_string,
        n_obs         = nrow(t_gaussian),
        n_used        = stats::nobs(fit),
        n_dropped     = nrow(t_gaussian) - stats::nobs(fit),
        aic           = round(stats::AIC(fit), 4),
        deviance      = round(stats::deviance(fit), 4),
        null_deviance = round(fit$null.deviance, 4),
        row.names     = NULL
    )
    out[order(out$term), ]
}

cat("== y ~ x1 + x2 ==\n")
fit2 <- stats::glm(y ~ x1 + x2, data = t_gaussian, family = stats::gaussian())
print(reference_table(fit2, "y ~ x1 + x2"), width = 200)

cat("\n== y ~ x1 ==\n")
fit1 <- stats::glm(y ~ x1, data = t_gaussian, family = stats::gaussian())
print(reference_table(fit1, "y ~ x1")[, c("term", "estimate")])
