# FbSQL

A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL

FbSQL is a PostgreSQL extension that proposes a statistical modeling DSL faithful
to SQL's design principles — set-oriented, declarative, closed over relations
(relation in, relation out), order-independent, and consistent with SQL's NULL
semantics. Models are specified with R's formula notation; fitting takes
relations and returns relations, with no model objects exposed. R (via PL/R) is
an internal engine only. `glm` is the first proof of concept.

## What works today

The canonical API is `fbsql.fit_glm()`. Run
`SET search_path TO fbsql, public;` once per session to write it unqualified.

```sql
SELECT term, estimate, std_error, p_value
FROM fbsql.fit_glm(
  relation => $$ SELECT churn_flag, age, gender FROM customer
                 WHERE DATE_PART('YEAR', created_at) = 2025 $$,
  formula  => 'churn_flag ~ age + gender',
  family   => 'binomial');
```

- Families: `gaussian` (identity link) and `binomial` (logit link); any other
  family raises a clear error.
- Text columns are treated as factors with `stats::glm()` conventions
  (sorted levels, first level as reference, treatment contrasts).
- Rows containing NULL are excluded (Complete Case Analysis, as in R's `glm()`)
  and reported explicitly via the `n_obs` / `n_used` / `n_dropped` columns.
- The output is a single relation — one row per model term with
  `term`, `estimate`, `std_error`, `statistic`, `p_value`, `conf_low_95`,
  `conf_high_95` (Wald), plus model-level columns repeated on every row:
  `family`, `link`, `formula`, `n_obs`, `n_used`, `n_dropped`, `aic`,
  `deviance`, `null_deviance`, and `metadata`.
- The `metadata` jsonb column records what the future `predict_glm()` needs to
  rebuild the design matrix (response, term labels, variable classes, factor
  levels, contrasts, coefficient names) — inspectable from SQL, e.g.
  `metadata -> 'xlevels'`.
- The R model object never leaves the function; results are verified against
  R's `stats::glm()` in the regression tests (`scripts/parity_reference.R`).

`fbsql.predict_glm()` scores a relation from a fitted model relation — no R
involved: predictions are computed in PL/pgSQL from the coefficients and
`metadata` alone. Currently numeric predictors + gaussian family only. It
returns `SETOF record`, so attach a column definition list:

```sql
SELECT *
FROM fbsql.predict_glm(
  relation => $$ SELECT id, x FROM t_new $$,
  model    => $$ SELECT * FROM t_model $$
) AS p(id integer, x double precision, y_predicted double precision);
```

The output is the input relation's rows plus `<response>_predicted`; rows with
NULL predictors get a NULL prediction.

## Not yet implemented

- `predict_glm()` for binomial models and factor predictors (including the
  planned `on_new_levels` policy for unseen factor levels).
- Other families, non-canonical links, `weights` / `offset`.

## Development

The development environment (PostgreSQL 16 + PL/R + R) is pinned with Docker:

```bash
scripts/docker-build.sh          # build the dev image
scripts/check-plr.sh             # verify CREATE EXTENSION plr works end-to-end
scripts/docker-installcheck.sh   # make install + pg_regress inside the image
```

See `docs/development.md` for details. Deferred work is tracked in `TODO.md`.

## License

MIT © Data Science Core
