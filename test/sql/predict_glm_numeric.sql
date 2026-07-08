-- predict_glm() MVP stage 1: numeric predictors, gaussian family.
-- Reference values in scripts/parity_reference.R (R predict.glm()).
CREATE TEMP TABLE t_train (
    y double precision,
    x double precision
);

INSERT INTO t_train VALUES
    (1.0, 0.0), (2.0, 1.0), (3.0, 2.0), (4.0, 3.0), (5.0, 4.0);

CREATE TEMP TABLE t_new (
    id integer,
    x  double precision
);

-- The NULL row must yield a NULL prediction (SQL NULL semantics; R's
-- predict() likewise returns NA).
INSERT INTO t_new VALUES (1, 1.5), (2, 3.5), (3, NULL);

CREATE TEMP TABLE t_model AS
SELECT *
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_train $$,
    formula  => 'y ~ x',
    family   => 'gaussian');

SELECT id, x, round(y_predicted::numeric, 4) AS y_predicted
FROM fbsql.predict_glm(
    relation => $$ SELECT id, x FROM t_new $$,
    model    => $$ SELECT * FROM t_model $$
) AS p(id integer, x double precision, y_predicted double precision)
ORDER BY id;
