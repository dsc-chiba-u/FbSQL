# FbSQL

[![PGXN version](https://badge.fury.io/pg/fbsql.svg)](https://badge.fury.io/pg/fbsql)
[![DOI](https://zenodo.org/badge/1292894034.svg)](https://doi.org/10.5281/zenodo.21404862)

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
`fbsql.predict_glm()`. This README is written as a tutorial: follow one
installation path below, then run [your first GLM](#your-first-glm).

## Installation

Pick one of four paths. **Docker is the easiest**: the image ships
PostgreSQL, R, PL/R, and FbSQL already wired together, so nothing needs to
be installed or matched on your machine. The PGXN paths install FbSQL into
a PostgreSQL you manage yourself — on Linux that is a few `apt` packages;
on macOS it additionally means building PL/R from source (Homebrew does
not package it).

### Recommended: Docker

The image bundles **PostgreSQL 16, R, PL/R, and the FbSQL extension** —
preinstalled and version-matched — for `linux/amd64` and `linux/arm64`
(Apple Silicon):

```bash
docker run --rm -d \
    --name fbsql \
    -p 5433:5432 \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    ghcr.io/dsc-chiba-u/fbsql:latest
```

(Also on Docker Hub as `koki/fbsql:latest`.) Host port **5433** is used so
the container never collides with a PostgreSQL already running on your
machine at the default 5432. Connect with:

```bash
psql -h localhost -p 5433 -U postgres -d postgres
```

If a container named `fbsql` already exists from a previous run, remove it
first with `docker rm -f fbsql`. `trust` authentication is a
development-only setting; do not expose this container.

Inside `psql`, activate the extension and check the version:

```sql
CREATE EXTENSION fbsql CASCADE;

SELECT fbsql.version();  -- 0.1.0
```

Now jump to [your first GLM](#your-first-glm).

### PGXN (Linux)

On Linux, **PL/R must be installed at the OS level first** — see
[about the PL/R dependency](#about-the-plr-dependency) below. On
Ubuntu 24.04 with PostgreSQL 16, everything comes from the standard
repositories:

```bash
sudo apt update
sudo apt install \
    postgresql-16 \
    postgresql-16-plr \
    r-base-core \
    pgxnclient
sudo pgxn install fbsql
```

Then, in `psql` (e.g. `sudo -u postgres psql`):

```sql
CREATE EXTENSION fbsql CASCADE;

SELECT fbsql.version();  -- 0.1.0
```

### PGXN (macOS)

FbSQL runs natively on macOS, including Apple Silicon (verified). The one
extra step is PL/R: **Homebrew does not package PL/R**, so it must be
built from source against your Homebrew PostgreSQL:

```bash
brew install postgresql@16 r pgxnclient
brew services start postgresql@16

# Make sure the matching pg_config is the one on PATH:
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"

# Build and install PL/R from source against that PostgreSQL:
git clone https://github.com/postgres-plr/plr.git
cd plr
USE_PGXS=1 make
USE_PGXS=1 make install

# Then install FbSQL from PGXN:
pgxn install fbsql
```

> **Version matching matters.** The PostgreSQL server you run, the
> `pg_config` on your PATH (used both to build PL/R and by
> `pgxn install`), and PL/R itself must all belong to the **same
> PostgreSQL major version** (here: 16). If you have several PostgreSQL
> installations, a mismatched `pg_config` silently installs the
> extensions into the wrong one, and `CREATE EXTENSION` later fails with
> `extension "plr" is not available`.

Then, in `psql` (e.g. `psql -p 5432 postgres`):

```sql
CREATE EXTENSION fbsql CASCADE;

SELECT fbsql.version();  -- 0.1.0
```

### Build from source

Requirements: PostgreSQL (developed and tested against 16) with PL/R
available (see above), which in turn needs R. From a source checkout
(uses PGXS via `pg_config`):

```bash
make install
```

```sql
CREATE EXTENSION fbsql CASCADE;
```

## About the PL/R dependency

`fit_glm()` runs R's `stats::glm()` through
[PL/R](https://github.com/postgres-plr/plr); `predict_glm()` is pure
PL/pgSQL and needs no R at runtime.

Two things are worth knowing:

- **`CASCADE` does not download PL/R.** `CREATE EXTENSION fbsql CASCADE`
  only *registers* the `plr` extension in your database — and that works
  only if PL/R is already installed at the OS level (the `postgresql-16-plr`
  package on Debian/Ubuntu, a source build on macOS, or nothing to do in
  the Docker image, where it is preinstalled).
- **`ERROR: extension "plr" is not available`** therefore does not point
  at FbSQL: it means PL/R is not installed for the PostgreSQL you are
  connected to. Go back to the installation step for your platform (and on
  macOS, re-check the version-matching note above).

PL/R is an untrusted language, so creating the extension requires
superuser; grant `EXECUTE` on the `fbsql` functions to regular users as
needed.

## Your first GLM

Everything below is plain SQL and works the same on every installation
path. First, a small dataset (a 10-row excerpt of R's classic `mtcars`,
included here so nothing needs to be imported):

```sql
CREATE TABLE mtcars (model text, mpg float8, hp float8, wt float8);
INSERT INTO mtcars VALUES
    ('Mazda RX4',         21.0, 110, 2.620),
    ('Mazda RX4 Wag',     21.0, 110, 2.875),
    ('Datsun 710',        22.8,  93, 2.320),
    ('Hornet 4 Drive',    21.4, 110, 3.215),
    ('Hornet Sportabout', 18.7, 175, 3.440),
    ('Valiant',           18.1, 105, 3.460),
    ('Duster 360',        14.3, 245, 3.570),
    ('Merc 240D',         24.4,  62, 3.190),
    ('Merc 230',          22.8,  95, 3.150),
    ('Merc 280',          19.2, 123, 3.440);
```

Fit a gaussian GLM of fuel efficiency on horsepower and weight:

```sql
SELECT *
FROM fbsql.fit_glm(
    'SELECT mpg, hp, wt FROM mtcars',
    'mpg ~ hp + wt',
    'gaussian');
```

The fitted model comes back **as a relation** — one row per model term
(`(Intercept)`, `hp`, `wt`), with the columns you would expect from R's
coefficient table (`estimate`, `std_error`, `statistic`, `p_value`, Wald
`conf_low_95`/`conf_high_95`), model-level columns repeated on every row
(`family`, `link`, `formula`, `n_obs`/`n_used`/`n_dropped`, `aic`,
`deviance`, `null_deviance`), and a `metadata` JSONB column that carries
everything prediction needs. Selecting just a few columns:

```
    term     | estimate | std_error | p_value
-------------+----------+-----------+---------
 (Intercept) |  30.5431 |    3.5670 |  0.0001
 hp          |  -0.0447 |    0.0101 |  0.0030
 wt          |  -1.4989 |    1.2734 |  0.2776
```

All numbers match `glm(mpg ~ hp + wt, data = ...)` in R. Named arguments
work too, and are the style used throughout the paper:
`fit_glm(relation => ..., formula => ..., family => ...)`.

Clean up when you are done:

```sql
DROP TABLE mtcars;
```

### Prediction

The model relation is all that `predict_glm()` needs — store it in a
table, then score any relation with the same predictor columns:

```sql
fbsql.predict_glm(
    relation      text,                -- SQL string: relation to score
    model         text,                -- SQL string: a model relation
    on_new_levels text DEFAULT 'error' -- 'error' | 'na'
) RETURNS SETOF record
```

Because it returns `SETOF record`, the caller attaches a column definition
list (the input columns plus `<response>_predicted`). See the full
fit-then-predict walkthrough in the running example below.

## Running example: customer churn

Fit a churn model on 2025 customers, then score 2026 customers — covered
end to end by the regression tests (`test/sql/running_example.sql`). The
examples are written with `SET search_path TO fbsql, public;` so the
functions appear unqualified:

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

`predict_glm()` computes predictions in PL/pgSQL from the coefficients and
`metadata` alone and returns the input relation's rows plus
`<response>_predicted`. Factor levels unseen at fit time raise an explicit
error by default, or yield NULL predictions with `on_new_levels => 'na'`;
NULL predictors always predict NULL.

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

Images are published by CI on every push to `main` (tags: `latest`, the
short commit SHA, and the version on release tags). See
`docs/development.md` for details. Deferred work is tracked in `TODO.md`.

## Related repositories

- [FbSQL-experiments](https://github.com/dsc-chiba-u/FbSQL-experiments) —
  reproducible comparisons against Apache MADlib, PostgresML, and Spark
  MLlib, plus the material behind the manuscript's tables and figures.

A paper on FbSQL's language design is in preparation; citation information
will be added on release. The 0.1.0 release is archived at Zenodo:
[10.5281/zenodo.21404862](https://doi.org/10.5281/zenodo.21404862).

## License

MIT © Data Science Core
