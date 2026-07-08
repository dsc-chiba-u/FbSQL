-- Fixture: small deterministic data with a text (categorical) predictor.
-- Kept literally in sync with scripts/parity_reference.R. R's conventions
-- apply: levels sorted ('F' < 'M' < 'Other'), first level is the reference
-- under treatment contrasts, so the terms are (Intercept), genderM,
-- genderOther.
CREATE TEMP TABLE t_factor (
    y      double precision,
    gender text
);

INSERT INTO t_factor VALUES
    (1.0, 'F'), (2.0, 'M'), (1.5, 'F'),
    (2.5, 'M'), (3.0, 'Other'), (2.8, 'Other');

SELECT term,
       round(estimate::numeric, 4)      AS estimate,
       round(std_error::numeric, 4)     AS std_error,
       round(statistic::numeric, 4)     AS statistic,
       round(p_value::numeric, 4)       AS p_value,
       round(conf_low_95::numeric, 4)   AS conf_low_95,
       round(conf_high_95::numeric, 4)  AS conf_high_95,
       family, link, formula,
       n_obs, n_used, n_dropped,
       round(aic::numeric, 4)           AS aic,
       round(deviance::numeric, 4)      AS deviance,
       round(null_deviance::numeric, 4) AS null_deviance
FROM fbsql.fit_glm(
    relation => $$ SELECT y, gender FROM t_factor $$,
    formula  => 'y ~ gender',
    family   => 'gaussian')
ORDER BY term COLLATE "C";  -- locale-independent row order for pg_regress
