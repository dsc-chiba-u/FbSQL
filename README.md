# FbSQL

A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL

FbSQL is a **PostgreSQL extension** — not an R package — that proposes a
statistical modeling DSL faithful to SQL's design principles: set-oriented,
declarative, closed over relations (relation in, relation out),
order-independent, and consistent with SQL's NULL semantics. Models are
specified with R's formula notation; both fitting and prediction take
relations and return relations, and no model object is ever exposed. R (via
PL/R) is only the internal fitting engine, and prediction runs without R at
all. `glm` is the first proof of concept.

The PoC API is two functions in the `fbsql` schema: `fbsql.fit_glm()` and
`fbsql.predict_glm()`. Run `SET search_path TO fbsql, public;` once per
session to write them unqualified.

## Installation

### Recommended (Docker)

The image bundles everything FbSQL needs — PostgreSQL 16, PL/R, R, and the
extension preinstalled — so nothing is installed on the host:

```bash
docker pull ghcr.io/dsc-chiba-u/fbsql:latest
# or, from Docker Hub:
docker pull koki/fbsql:latest
```

<!-- TODO: confirm the Docker Hub namespace (assumed `koki`, as in fbrglm)
     after the first successful publish run. -->

Start a server and create the extension:

```bash
docker run --rm -d --name fbsql -p 5432:5432 \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    ghcr.io/dsc-chiba-u/fbsql:latest
psql -h localhost -U postgres    # then: CREATE EXTENSION fbsql CASCADE;
```

(`trust` authentication is a development-only setting; do not expose this
container.) Images are published by CI on every push to `main` (tags:
`latest`, the short commit SHA, and the version on release tags). To build
the identical image locally instead:

```bash
scripts/docker-build.sh          # build the fbsql-dev image from this checkout
scripts/docker-installcheck.sh   # run the full test suite inside it
```

The test suite executes the running example below verbatim, so a green
`docker-installcheck.sh` also reproduces the paper's workflow end to end.

### Alternative (Build from source)

Requirements: PostgreSQL (developed and tested against 16) with the
[PL/R](https://github.com/postgres-plr/plr) extension available, which in
turn needs R. `fit_glm()` runs R's `stats::glm()` through PL/R;
`predict_glm()` is pure PL/pgSQL and needs no R at runtime.

From a source checkout (uses PGXS via `pg_config`):

```bash
make install
```

```sql
CREATE EXTENSION fbsql CASCADE;  -- CASCADE also installs the required plr
```

PL/R is an untrusted language, so creating the extension requires superuser;
grant `EXECUTE` on the `fbsql` functions to regular users as needed.

### Future (PGXN)

PGXN publication is planned; the release metadata already lives in
`META.json` and the change history in `Changes`. Once released,
installation will become:

```bash
pgxn install fbsql
```

```sql
CREATE EXTENSION fbsql;
```

## Running example: customer churn

Fit a churn model on 2025 customers, then score 2026 customers — covered
end to end by the regression tests (`test/sql/running_example.sql`):

```sql
CREATE TEMPORARY TABLE logit_model AS
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
        churn_flag_predicted double precision)
;
```

`fit_glm()` returns a single relation: one row per model term (`term`,
`estimate`, `std_error`, `statistic`, `p_value`, Wald `conf_low_95` /
`conf_high_95`) with model-level columns repeated on every row (`family`,
`link`, `formula`, `n_obs` / `n_used` / `n_dropped`, `aic`, `deviance`,
`null_deviance`) plus a `metadata` jsonb column carrying everything
prediction needs (factor levels, contrasts, term information) — inspectable
from SQL, e.g. `metadata -> 'xlevels'`.

`predict_glm()` computes predictions in PL/pgSQL from the coefficients and
`metadata` alone and returns the input relation's rows plus
`<response>_predicted`. It returns `SETOF record`, so a column definition
list is attached as in the example above.

## Supported today

- Families: `gaussian` (identity link) and `binomial` (logit link;
  predictions are probabilities, as R's `predict(..., type = "response")`)
- Numeric and factor predictors (text columns get `stats::glm()` factor
  conventions: sorted levels, first level as reference, treatment contrasts)
- NULL handling: rows containing NULL are excluded from fitting (Complete
  Case Analysis, reported via `n_obs` / `n_used` / `n_dropped`) and predict
  to NULL when a predictor is NULL
- Factor levels unseen at fit time: `on_new_levels => 'error'` (default) or
  `'na'` (NULL prediction for those rows only)
- All numeric results are verified against R's `stats::glm()` /
  `predict.glm()` in the regression tests (`scripts/parity_reference.R`)

## Not yet supported

- Interactions and custom contrasts
- `offset` / `weights`
- Prediction intervals; class prediction / a prediction `type` argument
- Families and links beyond gaussian/identity and binomial/logit
- Large-scale / distributed GLM fitting (out of scope: FbSQL's claim is
  language design, not statistical computing performance)

## Development

The published image doubles as the development environment — there is no
separate runtime image. The environment (PostgreSQL 16 + PL/R + R) is
pinned with Docker:

```bash
scripts/docker-build.sh          # build the dev image
scripts/check-plr.sh             # verify CREATE EXTENSION plr works end-to-end
scripts/docker-installcheck.sh   # make install + pg_regress inside the image
```

See `docs/development.md` for details. Deferred work is tracked in `TODO.md`.

## Related repositories

- [FbSQL-experiments](https://github.com/dsc-chiba-u/FbSQL-experiments) —
  reproducible comparisons against Apache MADlib, PostgresML, and Spark
  MLlib, plus the material behind the manuscript's tables and figures.

A software paper on FbSQL's language design is in preparation; citation
information will be added on release.

## License

MIT © Data Science Core
