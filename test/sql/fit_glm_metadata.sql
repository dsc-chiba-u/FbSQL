-- The metadata column (meta_version 1, docs/mvp-design.md section 4) carries
-- everything predict_glm() will need to rebuild the design matrix. jsonb
-- normalizes key order, so jsonb_pretty() and -> / ->> output are stable.
CREATE TEMP TABLE t_meta (
    y      double precision,
    x1     double precision,
    gender text
);

INSERT INTO t_meta VALUES
    (1.2, 0, 'F'), (2.3, 1, 'M'), (3.1, 2, 'Other'),
    (1.8, 3, 'F'), (2.9, 4, 'M'), (3.7, 5, 'Other'),
    (2.1, 6, 'F'), (3.3, 7, 'M'), (4.2, 8, 'Other');

-- DISTINCT proves every coefficient row carries the identical metadata.
SELECT DISTINCT jsonb_pretty(metadata) AS metadata
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1, gender FROM t_meta $$,
    formula  => 'y ~ x1 + gender',
    family   => 'gaussian');

-- Individual field access, as predict_glm() will consume it.
SELECT DISTINCT
       metadata ->> 'meta_version' AS meta_version,
       metadata ->> 'response'     AS response,
       metadata -> 'term_labels'   AS term_labels,
       metadata -> 'coef_terms'    AS coef_terms
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1, gender FROM t_meta $$,
    formula  => 'y ~ x1 + gender',
    family   => 'gaussian');

SELECT DISTINCT
       metadata -> 'data_classes' AS data_classes,
       metadata -> 'xlevels'      AS xlevels,
       metadata -> 'contrasts'    AS contrasts
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1, gender FROM t_meta $$,
    formula  => 'y ~ x1 + gender',
    family   => 'gaussian');

-- Numeric-only model: xlevels and contrasts must be empty objects.
SELECT DISTINCT
       metadata -> 'xlevels'    AS xlevels,
       metadata -> 'contrasts'  AS contrasts,
       metadata -> 'coef_terms' AS coef_terms
FROM fbsql.fit_glm(
    relation => $$ SELECT y, x1 FROM t_meta $$,
    formula  => 'y ~ x1');
