# Echo's tests on the lab

Goal: every Echo test that needs a database server gets it from echo-server-lab through a recipe,
talks to it only through our drivers, and runs the same locally and on GitHub CI. The decisions
below were made by the owner (2026-10-01). Failures the lab suites found are in
[TEST_FINDINGS.md](TEST_FINDINGS.md), each with a GitHub issue.

## How it works

- **A database suite** either has `@Suite(.enabled(if: labIntegrationEnabled, labIntegrationNote),
  .server("recipe"))` (Swift Testing, its own server, removed when the suite ends), or gets the
  server every suite of the run shares from `LabSharedServers` (`MSSQLLabTestCase`,
  `LabSharedServers.serverForSuite(recipe)`), removed when the test bundle finishes.
- **Recipes:** `LabRecipes` in `EchoTests/Integration/Lab/LabIntegration.swift`. SQL Server:
  `mssql-<version>-agent` and `mssql-<version>-adventureworks`, with the version from
  `ECHO_LAB_SQLSERVER_VERSION` (2022 when unset) and an optional `ECHO_LAB_SQLSERVER_COMPAT`.
- **Plans:**
  - **UnitTests:** no server; lab suites skip (`SERVERLAB_INTEGRATION` unset).
  - **EchoTests:** everything, lab suites on.
  - **SQLServerVersions:** the SQL Server suites in 8 configurations (2017, 2019, 2022, 2025, and
    2017 at compatibility levels 100, 110, 120 and 130).
- **CI:**
  - **CI (Light)**, pushes to `dev`: UnitTests.
  - **CI (Full)**, pull requests to `main` and by hand: UnitTests, then EchoTests against testlab
    over Tailscale.
  - **Nightly**, by hand: SQLServerVersions.

  The lab setup is one action, `.github/actions/lab-tests-setup`. Each run's servers are owned by
  `ci-<run>` or `nightly-<run>` and removed afterwards.
- **Locally:** run the EchoTests plan; testlab must be reachable (home network), or set
  `SERVERLAB_HOST=local` for Docker on the Mac.

## Where we are (2026-10-01)

- **On the lab:**
  - **SQL Server:** every suite (`MSSQLLabTestCase`, `MSSQLDedicatedLabTestCase`, Agent
    management, the integration and metadata-loading suites, the cross-dialect suites).
  - **Postgres:** the seven round 21/23 suites and the integration and backup suites.
  - **MySQL:** the integration suite.
- **Left until the driver switch** (hot path): the 26 `.disabled` files in
  `EchoTests/Integration/Postgres/` and `PostgresDockerTestCase`, which still use
  `EchoDockerManager`; the Postgres version matrix; `PostgresStreamingBenchmarkTests` (needs a
  recipe with a large table).
- **SQL Server content** is made through sqlserver-nio in each suite's scratch database; the SQL
  text left is what a user types in a query tab, plus two driver gaps (GS-03 compressed tables,
  tashda/sqlserver-nio#15; GS-41 finishing a restore, tashda/sqlserver-nio#16).
- **Removed:** the old plans (IntegrationTests, MSSQLCompatibilityTests,
  PostgresCompatibilityTests, SQLiteIntegrationTests) and the self-hosted runner's workflow and
  scripts. `EchoDockerManager` and `.ci-fixtures` stay until the disabled Postgres files move.

## Decisions

| Question | Decision |
|---|---|
| How CI reaches the lab | Tailscale in the workflow; testlab advertises itself as a subnet route |
| Server variables | One URL convention (`echo-server-lab/docs/driver-test-convention.md`) |
| The 28 disabled files | Port onto lab recipes (Postgres ones after the driver switch) |
| Raw SQL setup | Move to recipes or typed APIs as each file migrates |
| Problems found but not fixed | A GitHub issue each, and an entry in TEST_FINDINGS.md |
