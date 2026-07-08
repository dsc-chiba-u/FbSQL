-- Verify that PL/R is available and actually executes R inside PostgreSQL.

SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name = 'plr';

CREATE EXTENSION IF NOT EXISTS plr;

-- Prove that R code runs end-to-end, not just that the extension installs.
CREATE OR REPLACE FUNCTION fbsql_check_r_version() RETURNS text AS
'R.version.string'
LANGUAGE plr;

SELECT fbsql_check_r_version() AS r_version;

DROP FUNCTION fbsql_check_r_version();
