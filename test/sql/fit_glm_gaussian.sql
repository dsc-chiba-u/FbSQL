-- Fixture: small deterministic gaussian data with hand-written residuals
-- around y = 2 + 1.5*x1 - 0.5*x2. Kept literally in sync with
-- scripts/parity_reference.R (a perfect fit would make std errors and
-- p-values numerically unstable, so the residuals are deliberate).
CREATE TEMP TABLE t_gaussian (
    y  double precision,
    x1 double precision,
    x2 double precision
);

INSERT INTO t_gaussian VALUES
    (-0.3, 0, 5), (1.9, 1, 3), (1.3, 2, 8), (5.7, 3, 1),
    (3.5, 4, 9), (7.6, 5, 4), (7.3, 6, 7), (11.7, 7, 2),
    (10.9, 8, 6), (15.6, 9, 0), (11.7, 10, 10), (17.1, 11, 3);

-- Full output relation. Floating-point columns are rounded so the expected
-- output is platform-stable; row order is not guaranteed by design (order
-- independence), hence the explicit ORDER BY.
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
    relation => $$ SELECT y, x1, x2 FROM t_gaussian $$,
    formula  => 'y ~ x1 + x2',
    family   => 'gaussian')
ORDER BY term;

-- family defaults to gaussian.
SELECT term, round(estimate::numeric, 4) AS estimate
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1 FROM t_gaussian $$,
    formula  => 'y ~ x1')
ORDER BY term;

-- Unsupported family must fail with a clear error.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1 FROM t_gaussian $$,
    formula  => 'y ~ x1',
    family   => 'poisson');
