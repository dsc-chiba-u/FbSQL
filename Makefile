EXTENSION = fbsql
DATA = sql/fbsql--0.1.0.sql

REGRESS = fbsql_version
REGRESS_OPTS = --inputdir=test --outputdir=test

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
