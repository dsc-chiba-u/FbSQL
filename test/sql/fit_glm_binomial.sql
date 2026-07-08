-- Fixture: small deterministic binomial data. 0s and 1s are interleaved
-- across the x range so there is no complete separation. Kept literally in
-- sync with scripts/parity_reference.R.
CREATE TEMP TABLE t_binomial (
    y integer,
    x double precision
);

INSERT INTO t_binomial VALUES
    (0, 0.1), (0, 0.4), (1, 0.8), (0, 1.0),
    (1, 1.2), (0, 1.5), (1, 1.8), (1, 2.0),
    (0, 2.2), (1, 2.5), (1, 2.8), (0, 3.0);

-- Full output relation (statistic is the z value for binomial).
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
    relation => $$ SELECT y, x FROM t_binomial $$,
    formula  => 'y ~ x',
    family   => 'binomial')
ORDER BY term;

-- A boolean response (as in the running example's churn_flag) must give the
-- same fit as the 0/1 integer encoding.
SELECT term,
       round(estimate::numeric, 4) AS estimate,
       round(std_error::numeric, 4) AS std_error
FROM fbsql.fit_glm(
    relation => $$ SELECT y::boolean AS y, x FROM t_binomial $$,
    formula  => 'y ~ x',
    family   => 'binomial')
ORDER BY term;
