-- The paper's running example, end to end: fit a churn model on 2025
-- customers, predict churn probabilities for 2026 customers.
-- Reference values in scripts/parity_reference.R.
CREATE TEMP TABLE customer (
    customer_id VARCHAR,
    created_at  TIMESTAMP,
    age         INTEGER,
    gender      VARCHAR,
    churn_flag  BOOLEAN
);

-- 2025: training data. churn rises with age within each gender but stays
-- non-monotone overall, so the logit fit converges without separation.
INSERT INTO customer VALUES
    ('c001', '2025-01-15', 25, 'F',     false),
    ('c002', '2025-02-20', 34, 'F',     false),
    ('c003', '2025-03-10', 48, 'F',     true),
    ('c004', '2025-04-05', 52, 'F',     true),
    ('c005', '2025-05-12', 28, 'M',     false),
    ('c006', '2025-06-18', 39, 'M',     true),
    ('c007', '2025-07-22', 45, 'M',     false),
    ('c008', '2025-08-30', 58, 'M',     true),
    ('c009', '2025-09-14', 23, 'Other', false),
    ('c010', '2025-10-08', 37, 'Other', false),
    ('c011', '2025-11-25', 49, 'Other', true),
    ('c012', '2025-12-19', 61, 'Other', true);

-- 2026: scoring data (churn unknown). c104 has a NULL age; c105 has a
-- gender level unseen in 2025.
INSERT INTO customer VALUES
    ('c101', '2026-01-10', 30,   'F',         NULL),
    ('c102', '2026-02-15', 55,   'M',         NULL),
    ('c103', '2026-03-20', 42,   'Other',     NULL),
    ('c104', '2026-04-25', NULL, 'F',         NULL),
    ('c105', '2026-05-30', 36,   'Nonbinary', NULL);

CREATE TEMP TABLE logit_model AS
SELECT *
FROM
 fbsql.fit_glm(
  relation => $$
   SELECT churn_flag, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2025
  $$,
  formula => 'churn_flag ~ age + gender',
  family => 'binomial')
;

SELECT term,
       round(estimate::numeric, 4)  AS estimate,
       round(std_error::numeric, 4) AS std_error,
       family, link, n_obs, n_used, n_dropped
FROM logit_model
ORDER BY term COLLATE "C";

-- Predict churn probabilities for 2026 customers (novel-level row excluded
-- here; the default policy is exercised against it below).
SELECT customer_id, round(churn_flag_predicted::numeric, 4) AS churn_flag_predicted
FROM
 fbsql.predict_glm(
  relation => $$
   SELECT customer_id, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2026
     AND customer_id <> 'c105'
  $$,
  model => $$ SELECT * FROM logit_model $$
 ) AS p(customer_id varchar, age integer, gender varchar,
        churn_flag_predicted double precision)
ORDER BY customer_id;

-- The unseen gender level aborts under the default policy...
SELECT customer_id, churn_flag_predicted
FROM
 fbsql.predict_glm(
  relation => $$
   SELECT customer_id, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2026
  $$,
  model => $$ SELECT * FROM logit_model $$
 ) AS p(customer_id varchar, age integer, gender varchar,
        churn_flag_predicted double precision);

-- ...and predicts NULL for exactly that row under on_new_levels => 'na'.
SELECT customer_id, round(churn_flag_predicted::numeric, 4) AS churn_flag_predicted
FROM
 fbsql.predict_glm(
  relation => $$
   SELECT customer_id, age, gender
   FROM customer
   WHERE DATE_PART('YEAR', created_at) = 2026
  $$,
  model         => $$ SELECT * FROM logit_model $$,
  on_new_levels => 'na'
 ) AS p(customer_id varchar, age integer, gender varchar,
        churn_flag_predicted double precision)
ORDER BY customer_id;
