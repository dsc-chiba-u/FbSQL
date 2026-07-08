# Development / test environment for FbSQL: PostgreSQL + PL/R + R.
#
# Stability over freshness: we use the PGDG postgres:16 image (Debian bookworm)
# and the distribution-packaged PL/R (postgresql-16-plr) instead of building
# PL/R from source. postgresql-server-dev-16 and make are included so that
# `CREATE EXTENSION fbsql` (via PGXS `make install`) and pg_regress can run
# inside this image later.
FROM postgres:16-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-16-plr \
        r-base-core \
        postgresql-server-dev-16 \
        make \
    && rm -rf /var/lib/apt/lists/*

# Install the plr extension into the default database at first startup.
COPY docker/initdb/10-plr.sql /docker-entrypoint-initdb.d/10-plr.sql

# Bake the fbsql extension into the image so `CREATE EXTENSION fbsql`
# works out of the box in the published image. The development workflow
# still mounts the checkout and reinstalls with `make install`, which
# simply overwrites these files.
COPY Makefile fbsql.control /opt/fbsql/
COPY sql /opt/fbsql/sql
RUN make -C /opt/fbsql install
