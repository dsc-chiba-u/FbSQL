-- Fixture: the 12 complete rows of the t_gaussian fixture plus 3 rows that
-- contain NULL (one NULL response, two NULL predictors). Complete Case
-- Analysis must drop exactly those 3 rows, so the coefficients below must
-- match the fit_glm_gaussian test verbatim.
CREATE TEMP TABLE t_nulls (
    y  double precision,
    x1 double precision,
    x2 double precision
);

INSERT INTO t_nulls VALUES
    (-0.3, 0, 5), (1.9, 1, 3), (1.3, 2, 8), (5.7, 3, 1),
    (3.5, 4, 9), (7.6, 5, 4), (7.3, 6, 7), (11.7, 7, 2),
    (10.9, 8, 6), (15.6, 9, 0), (11.7, 10, 10), (17.1, 11, 3),
    (NULL, 12, 4), (99.9, NULL, 2), (50.0, 13, NULL);

SELECT term,
       round(estimate::numeric, 4)  AS estimate,
       round(std_error::numeric, 4) AS std_error,
       n_obs, n_used, n_dropped
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1, x2 FROM t_nulls $$,
    formula  => 'y ~ x1 + x2',
    family   => 'gaussian')
ORDER BY term;
