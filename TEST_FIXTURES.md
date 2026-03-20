# Test Fixture Policy

Echo consumes package-owned database fixtures. It does not treat ambient Docker containers as valid test environments.

## Rules

- Database integration fixtures always run through `bootstrap`, `validate`, and `repair/recreate`.
- Validation is mandatory on every run, even when Docker containers are reused.
- Fixture failures must surface as fixture/bootstrap failures, not as Echo regressions.
- Echo UI tests are separate from database integration tests.

## Canonical Providers

- MSSQL: `sqlserver-nio`
  - library: `ensureSQLServerTestFixture(requireAdventureWorks:)`
  - CLI: `swift run --package-path ../sqlserver-nio sqlserver-test-fixture --require-adventureworks`
- PostgreSQL: `postgres-wire`
  - library: `ensurePostgresTestFixture()`
  - CLI: `swift run --package-path ../postgres-wire postgres-test-fixture`

## Workflow Expectations

- The self-hosted runner only guarantees Colima and Docker availability.
- Fixture validity is established by the package bootstrap steps in the repo workflows.
- Echo database integration uses `DatabaseIntegrationTests.xctestplan`.
- Echo UI automation uses the separate `EchoUITests.xctestplan` workflow lane.
