# Test findings

Failures the lab suites turned up that are not mistakes in the tests. Each entry says what fails,
why, and who fixes it, and has a GitHub issue. When a fix lands, delete its entry and close its
issue in the same commit ("Fixes #N"), so this page always lists what is still open. Run one suite with:

```bash
xcodebuild test -project Echo.xcodeproj -scheme Echo -testPlan EchoTests -only-testing:EchoTests/<Suite>
```

(or `test_macos` through XcodeBuildMCP with the same arguments).

## Open

### F1. A query tab reads table structure from the wrong database (Echo, SQL Server)

- **Issue:** [tashda/Echo#28](https://github.com/tashda/Echo/issues/28)
- **Test:** `MSSQLIntegrationTests/testDedicatedSessionCanQueryAdventureWorksEmployeeAndContinue`
  (recipe `mssql-2022-adventureworks`).
- **What happens:** a query tab on AdventureWorks reads `HumanResources.Employee`, but
  `getTableStructureDetails(schema:table:)` on the same tab returns no columns.
- **Why:** `MSSQLDedicatedQuerySession+Delegation.swift` hands the call to the shared metadata
  session without the tab's current database (`connection.currentDatabase`), so it looks in the
  connection's default database. The other metadata calls delegated the same way (indexes,
  maintenance, …) probably have the same problem.
- **Fix:** Echo, `Dialects/MSSQL` (pass the tab's database; `SQLServerSessionAdapter` already has
  `getTableStructureDetails(schema:table:database:)`).

### F2. Bundled pg_dump and pg_restore do not start (Echo packaging, Postgres)

- **Issue:** [tashda/Echo#29](https://github.com/tashda/Echo/issues/29)
- **Test:** `PostgresBackupRestoreIntegrationTests` (27 of 29 fail).
- **What happens:** `pg_dump` and `pg_restore` in `Tools/PostgresTools` exit with status 6:
  dyld cannot load `/opt/homebrew/Cellar/openssl@3/3.6.1/lib/libcrypto.3.dylib`. The copied
  OpenSSL libraries still point at the Homebrew version they were copied from, so the tools break
  as soon as Homebrew's OpenSSL is upgraded (and on any Mac without that exact version). `psql`,
  which the plain-SQL test needs, is not bundled at all.
- **Why:** the copy step (CI's "Install PostgreSQL tools" and its local equivalent) copies the
  dylibs without rewriting their install names to `@loader_path`.
- **Fix:** the driver agent (libpq and OpenSSL are being rebuilt for the driver switch); until
  then the release's bundled tools are affected too.

### F3. A Postgres INSERT reports 0 affected rows (Postgres driver)

- **Issue:** [tashda/Echo#30](https://github.com/tashda/Echo/issues/30)
- **Test:** `PostgresIntegrationTests/testExecuteUpdateDDL`.
- **What happens:** `executeUpdate("INSERT … VALUES ('Alice'), ('Bob')")` on a `PostgresSession`
  returns 0 instead of 2.
- **Fix:** the driver agent (`Dialects/Postgres` is being rewritten on libpq).

### F4. Echo cannot log in to MySQL 8.4 without TLS (MySQL driver)

- **Issue:** [tashda/Echo#31](https://github.com/tashda/Echo/issues/31)
- **Test:** `MySQLIntegrationTests` (all 4), recipe `mysql-8.4-empty`.
- **What happens:** "Access denied for user 'root'" with the right password. MySQL 8.4 logs in
  with `caching_sha2_password`, whose first login without TLS needs the RSA key exchange that
  mysql-nio does not do.
- **Fix:** the driver agent (MariaDB Connector/C handles it). Until then a connection with TLS
  works.
