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

-- Binomial models are not supported by this stage.
CREATE TEMP TABLE t_train_b (y integer, x double precision);
INSERT INTO t_train_b VALUES
    (0, 0.1), (0, 0.4), (1, 0.8), (0, 1.0), (1, 1.2), (0, 1.5),
    (1, 1.8), (1, 2.0), (0, 2.2), (1, 2.5), (1, 2.8), (0, 3.0);
CREATE TEMP TABLE t_model_b AS
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, x FROM t_train_b $$,
    formula  => 'y ~ x',
    family   => 'binomial');
SELECT * FROM fbsql.predict_glm(
    relation => $$ SELECT x FROM t_train_b $$,
    model    => $$ SELECT * FROM t_model_b $$
) AS p(x double precision, y_predicted double precision);

-- Factor predictors are not supported by this stage.
CREATE TEMP TABLE t_train_f (y double precision, g text);
INSERT INTO t_train_f VALUES (1.0, 'a'), (2.0, 'b'), (1.5, 'a'), (2.5, 'b');
CREATE TEMP TABLE t_model_f AS
SELECT * FROM fbsql.fit_glm(
    relation => $$ SELECT y, g FROM t_train_f $$,
    formula  => 'y ~ g');
SELECT * FROM fbsql.predict_glm(
    relation => $$ SELECT g FROM t_train_f $$,
    model    => $$ SELECT * FROM t_model_f $$
) AS p(g text, y_predicted double precision);
