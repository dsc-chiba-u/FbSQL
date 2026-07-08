-- CASCADE also installs the required plr extension into the test database.
CREATE EXTENSION fbsql CASCADE;
SELECT fbsql.version();
