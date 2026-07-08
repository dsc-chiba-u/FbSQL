-- FbSQL 0.1.0 install script.
\echo Use "CREATE EXTENSION fbsql" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS fbsql;

-- Placeholder function so the extension skeleton is testable end-to-end.
CREATE FUNCTION fbsql.version()
RETURNS text
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
AS $$ SELECT 'FbSQL development version'::text $$;

-- Output relation of fit_glm(): one row per design-matrix column, plus
-- model-level columns repeated on every row. Keeping everything in a single
-- relation is a deliberate trade-off to preserve closure (relation in,
-- relation out); see docs/mvp-design.md section 3.
CREATE TYPE fbsql.glm_fit AS (
    term          text,
    estimate      double precision,
    std_error     double precision,
    statistic     double precision,
    p_value       double precision,
    conf_low_95   double precision,
    conf_high_95  double precision,
    family        text,
    link          text,
    formula       text,
    n_obs         bigint,
    n_used        bigint,
    n_dropped     bigint,
    aic           double precision,
    deviance      double precision,
    null_deviance double precision
);

-- MVP: gaussian and binomial families. R's model object never leaves this
-- function; callers only ever see the relation above.
CREATE FUNCTION fbsql.fit_glm(
    relation text,
    formula  text,
    family   text DEFAULT 'gaussian'
) RETURNS SETOF fbsql.glm_fit
LANGUAGE plr
AS $fit_glm$
    ## Validate arguments up front and surface clean PostgreSQL errors via
    ## pg.throwerror() instead of raw R evaluation errors.
    if (is.null(relation) || is.na(relation) || !nzchar(relation))
        pg.throwerror("fit_glm: relation must be a non-empty SQL string")
    if (is.null(formula) || is.na(formula) || !nzchar(formula))
        pg.throwerror("fit_glm: formula must be a non-empty R formula string")
    supported <- c("gaussian", "binomial")
    if (is.null(family) || is.na(family) || !(family %in% supported))
        pg.throwerror(sprintf(
            "fit_glm: family '%s' is not supported yet (supported families: %s)",
            family, paste(supported, collapse = ", ")))
    ## Canonical links only for now (gaussian: identity, binomial: logit).
    fam <- switch(family,
                  gaussian = stats::gaussian(),
                  binomial = stats::binomial())

    df <- pg.spi.exec(relation)
    if (!is.data.frame(df) || nrow(df) == 0L)
        pg.throwerror("fit_glm: relation returned no rows")

    ## PL/R hands text columns over as character vectors and R >= 4 no
    ## longer auto-factors them in data.frame(). glm()'s model.frame would
    ## convert them implicitly, but we convert explicitly so the behavior
    ## is deterministic and documented: levels are factor()'s sorted unique
    ## values, the first level is the reference (treatment contrasts, as in
    ## stats::glm() defaults). The future predict_glm() metadata (xlevels)
    ## will rely on exactly this convention.
    df[] <- lapply(df, function(col) if (is.character(col)) factor(col) else col)

    ## Rows containing NULL are dropped by glm()'s default na.action
    ## (na.omit) = Complete Case Analysis; the counts below make the
    ## dropped rows explicit instead of silent.
    n_obs <- nrow(df)
    fit <- stats::glm(stats::as.formula(formula), data = df, family = fam)
    n_used <- stats::nobs(fit)

    coefs <- summary(fit)$coefficients
    ## Wald intervals (confint.default): deterministic and cheap, unlike
    ## profile-likelihood confint(); documented in docs/mvp-design.md.
    ci <- stats::confint.default(fit)

    data.frame(
        term          = rownames(coefs),
        estimate      = coefs[, 1L],
        std_error     = coefs[, 2L],
        statistic     = coefs[, 3L],
        p_value       = coefs[, 4L],
        conf_low_95   = ci[, 1L],
        conf_high_95  = ci[, 2L],
        family        = family,
        link          = fam$link,
        formula       = formula,
        n_obs         = n_obs,
        n_used        = n_used,
        n_dropped     = n_obs - n_used,
        aic           = stats::AIC(fit),
        deviance      = stats::deviance(fit),
        null_deviance = fit$null.deviance,
        stringsAsFactors = FALSE
    )
$fit_glm$;
