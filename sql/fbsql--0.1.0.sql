-- FbSQL 0.1.0 install script.
\echo Use "CREATE EXTENSION fbsql" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS fbsql;

-- Placeholder function so the extension skeleton is testable end-to-end.
CREATE FUNCTION fbsql.version()
RETURNS text
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
AS $$ SELECT 'FbSQL development version'::text $$;
