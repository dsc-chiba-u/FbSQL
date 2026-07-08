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
    null_deviance double precision,
    -- Everything predict_glm() needs to rebuild the design matrix, repeated
    -- on every row like the other model-level columns (meta_version 1; see
    -- docs/mvp-design.md section 4 for the schema).
    metadata      jsonb
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

    fml <- tryCatch(stats::as.formula(formula),
                    error = function(e) pg.throwerror(sprintf(
                        "fit_glm: invalid formula: '%s'", formula)))

    ## Do NOT wrap pg.spi.exec in tryCatch: a failed SPI call aborts the
    ## transaction, and raising a fresh error from an R handler on top of
    ## that state crashes the backend. Letting the native PostgreSQL error
    ## propagate is both safe and the clearest message (e.g. relation
    ## "no_such_table" does not exist).
    df <- pg.spi.exec(relation)
    if (!is.data.frame(df) || nrow(df) == 0L)
        pg.throwerror("fit_glm: relation returned no rows")

    ## Fail fast with the offending names when the formula references
    ## columns the relation does not provide ('.' expands to all columns,
    ## so it is exempt).
    missing_cols <- setdiff(setdiff(all.vars(fml), "."), names(df))
    if (length(missing_cols) > 0L)
        pg.throwerror(sprintf(
            "fit_glm: formula references column(s) not in relation: %s (available: %s)",
            paste(missing_cols, collapse = ", "),
            paste(names(df), collapse = ", ")))

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
    ## Prefix R-level fitting errors (non-convergence, invalid response for
    ## the family, ...) with the function name; the R message itself is kept
    ## because it is usually the most informative part.
    fit <- tryCatch(stats::glm(fml, data = df, family = fam),
                    error = function(e) pg.throwerror(sprintf(
                        "fit_glm: %s", conditionMessage(e))))
    n_used <- stats::nobs(fit)

    coefs <- summary(fit)$coefficients
    ## Wald intervals (confint.default): deterministic and cheap, unlike
    ## profile-likelihood confint(); documented in docs/mvp-design.md.
    ci <- stats::confint.default(fit)

    ## ---- metadata (meta_version 1; docs/mvp-design.md section 4) ----
    ## JSON is built by hand because only base R is available in the PL/R
    ## runtime (no jsonlite). jsonb normalizes key order on the PostgreSQL
    ## side, so the field order below does not affect test stability.
    esc <- function(x) {
        x <- gsub("\\", "\\\\", x, fixed = TRUE)
        gsub('"', '\\"', x, fixed = TRUE)
    }
    jstr <- function(x) paste0('"', esc(as.character(x)), '"')
    jarr <- function(xs) paste0("[",
        paste(vapply(xs, jstr, character(1L)), collapse = ","), "]")
    jobj <- function(vals) {
        if (length(vals) == 0L) return("{}")
        paste0("{", paste(paste0(jstr(names(vals)), ":", unlist(vals)),
                          collapse = ","), "}")
    }

    tt <- stats::terms(fit)
    response_name <- deparse(attr(tt, "variables")[[attr(tt, "response") + 1L]])
    metadata <- paste0(
        '{"meta_version":1,',
        '"response":', jstr(response_name), ",",
        '"term_labels":', jarr(attr(tt, "term.labels")), ",",
        '"intercept":', if (attr(tt, "intercept") == 1L) "true" else "false", ",",
        '"data_classes":', jobj(lapply(attr(tt, "dataClasses"), jstr)), ",",
        '"xlevels":', jobj(lapply(fit$xlevels, jarr)), ",",
        '"contrasts":', jobj(lapply(fit$contrasts,
                                    function(x) jstr(as.character(x)))), ",",
        '"coef_terms":', jarr(names(stats::coef(fit))),
        "}")

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
        metadata      = metadata,
        stringsAsFactors = FALSE
    )
$fit_glm$;

-- predict_glm() MVP (stage 1): numeric predictors, gaussian family only.
-- Deliberately implemented WITHOUT R: predictions are computed from the
-- coefficient relation plus its metadata column alone, demonstrating that
-- the relation really is a complete model representation.
--
-- Returns SETOF record, so callers attach a column definition list:
--   SELECT * FROM fbsql.predict_glm(...) AS p(id int, x float8,
--                                             y_predicted float8);
-- The output is the input relation's rows with one appended column named
-- <response>_predicted. Rows whose predictors contain NULL get a NULL
-- prediction (SQL NULL semantics; matches R's predict() returning NA).
CREATE FUNCTION fbsql.predict_glm(
    relation text,
    model    text
) RETURNS SETOF record
LANGUAGE plpgsql
AS $predict_glm$
DECLARE
    meta   jsonb;
    fam    text;
    coefs  jsonb;
    n_rows bigint;
    expr   text := '0';
    term   text;
BEGIN
    IF relation IS NULL OR relation = '' THEN
        RAISE EXCEPTION 'predict_glm: relation must be a non-empty SQL string';
    END IF;
    IF model IS NULL OR model = '' THEN
        RAISE EXCEPTION 'predict_glm: model must be a non-empty SQL string';
    END IF;

    EXECUTE format('SELECT m.metadata, m.family FROM (%s) m LIMIT 1', model)
        INTO meta, fam;
    IF meta IS NULL THEN
        RAISE EXCEPTION 'predict_glm: model relation returned no rows or has NULL metadata';
    END IF;
    IF (meta ->> 'meta_version')::int IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION 'predict_glm: unsupported metadata version: %',
            meta ->> 'meta_version';
    END IF;
    IF fam IS DISTINCT FROM 'gaussian' THEN
        RAISE EXCEPTION 'predict_glm: family ''%'' is not supported yet (supported families: gaussian)',
            fam;
    END IF;
    -- R dataClasses maps every numeric SQL column to 'numeric', so any
    -- other class (factor, logical, ...) is outside this MVP scope.
    IF EXISTS (SELECT 1 FROM jsonb_each_text(meta -> 'data_classes') dc
               WHERE dc.value <> 'numeric') THEN
        RAISE EXCEPTION 'predict_glm: only numeric predictors are supported yet (data_classes: %)',
            meta -> 'data_classes';
    END IF;

    EXECUTE format('SELECT jsonb_object_agg(m.term, m.estimate), count(*) FROM (%s) m',
                   model)
        INTO coefs, n_rows;
    -- The model relation has no guaranteed row order (order independence),
    -- so coefficients are matched by term name and checked for completeness
    -- against metadata.coef_terms.
    IF n_rows IS DISTINCT FROM jsonb_array_length(meta -> 'coef_terms') THEN
        RAISE EXCEPTION 'predict_glm: model relation has % coefficient rows but metadata.coef_terms lists %',
            n_rows, jsonb_array_length(meta -> 'coef_terms');
    END IF;

    FOR term IN
        SELECT t.value FROM jsonb_array_elements_text(meta -> 'coef_terms') t
    LOOP
        IF coefs ->> term IS NULL THEN
            RAISE EXCEPTION 'predict_glm: coefficient row for term ''%'' is missing from the model relation',
                term;
        END IF;
        IF term = '(Intercept)' THEN
            expr := expr || format(' + (%L)::double precision', coefs ->> term);
        ELSE
            expr := expr || format(' + (%L)::double precision * r.%I',
                                   coefs ->> term, term);
        END IF;
    END LOOP;

    RETURN QUERY EXECUTE format(
        'SELECT r.*, (%s)::double precision AS %I FROM (%s) r',
        expr, (meta ->> 'response') || '_predicted', relation);
END;
$predict_glm$;
