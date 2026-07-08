EXTENSION = fbsql
DATA = sql/fbsql--0.1.0.sql

REGRESS = fbsql_version fit_glm_gaussian fit_glm_binomial fit_glm_nulls fit_glm_factor fit_glm_errors fit_glm_metadata predict_glm_numeric predict_glm_binomial predict_glm_factor running_example
REGRESS_OPTS = --inputdir=test --outputdir=test

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
