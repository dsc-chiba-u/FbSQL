# FbSQL

A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL

FbSQL is a PostgreSQL extension that proposes a statistical modeling DSL faithful
to SQL's design principles — set-oriented, declarative, closed over relations
(relation in, relation out), order-independent, and consistent with SQL's NULL
semantics. Models are specified with R's formula notation; both fitting and
prediction take relations and return relations, with no model objects exposed.
`glm` is the first proof of concept.

```sql
SELECT *
FROM
 fit_glm(
  relation => $$ SELECT * FROM customer
                 WHERE DATE_PART('YEAR', created_at) = 2025 $$,
  formula  => 'churn_flag ~ age + gender',
  family   => 'binomial')
;
```

The canonical name is `fbsql.fit_glm()`; run `SET search_path TO fbsql, public;`
once per session to write it unqualified as above.

## Status

Early proof of concept — `fbsql.fit_glm()` currently supports the gaussian
family only, implemented in PL/R on top of R's `stats::glm()`. The MVP
specification lives in `docs/mvp-design.md` (in Japanese), and deferred work
is tracked in `TODO.md`.

## Development

The development environment (PostgreSQL 16 + PL/R + R) is pinned with Docker:

```bash
scripts/docker-build.sh   # build the dev image
scripts/check-plr.sh      # verify CREATE EXTENSION plr works end-to-end
```

See `docs/development.md` for details.

## License

MIT © Data Science Core
