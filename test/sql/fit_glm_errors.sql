-- Error handling of fbsql.fit_glm(). Every failure must surface a clear,
-- 'fit_glm:'-prefixed message (PL/R wraps it in DETAIL).
CREATE TEMP TABLE t_err (
    y double precision,
    x double precision
);

INSERT INTO t_err VALUES (1.0, 0.1), (2.0, 0.9), (3.1, 2.1), (3.9, 3.0);

-- Unsupported family.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_err $$,
    formula  => 'y ~ x',
    family   => 'poisson');

-- Formula string that does not parse as an R formula.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_err $$,
    formula  => 'not a formula');

-- Formula referencing a column the relation does not provide.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_err $$,
    formula  => 'y ~ missing_col');

-- Broken relation SQL.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT * FROM no_such_table $$,
    formula  => 'y ~ x');

-- Relation that yields zero rows.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_err WHERE false $$,
    formula  => 'y ~ x');

-- R-level fitting error (binomial response outside [0, 1]) keeps R's
-- informative message, prefixed with the function name.
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_err $$,
    formula  => 'y ~ x',
    family   => 'binomial');
