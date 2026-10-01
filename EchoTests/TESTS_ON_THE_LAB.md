# Echo's tests on the lab

Goal: every Echo test that needs a database server gets it from echo-server-lab through a recipe,
talks to it only through our drivers, and runs the same locally and on GitHub CI. The decisions
below were made by the owner (2026-10-01). Failures the lab suites found are in
[TEST_FINDINGS.md](TEST_FINDINGS.md), each with a GitHub issue.

## How it works

- **A database suite** either has `@Suite(.enabled(if: labIntegrationEnabled, labIntegrationNote),
  .server("recipe"))` (Swift Testing, its own server, removed when the suite ends), or gets the
  server every suite of the run shares from `LabSharedServers` (`MSSQLLabTestCase`,
  `labServer(recipe)` in any XCTest), removed when the test bundle finishes; servers of a test
  process that was killed are removed by the next one (owners `EchoTests@<machine>:<pid>`).
- **Recipes:** `LabRecipes` in `EchoTests/Integration/Lab/LabIntegration.swift`. SQL Server:
  `mssql-<version>-agent` and `mssql-<version>-adventureworks`, with the version from
  `ECHO_LAB_SQLSERVER_VERSION` (2022 when unset) and an optional `ECHO_LAB_SQLSERVER_COMPAT`.
- **Plans:**
  - **UnitTests:** no server; lab suites skip (`SERVERLAB_INTEGRATION` unset).
  - **EchoTests:** everything, lab suites on (local use).
  - **LabTests:** only the suites that use lab servers, in one process, with time limits (CI's
    lab job). `LabTestPlansTests` (a unit test) fails when a lab suite is missing from it or, for
    SQL Server suites, from SQLServerVersions, and when a Swift Testing lab suite has no
    `.timeLimit`. Adding a lab suite therefore means: add it to LabTests (and SQLServerVersions
    for `MSSQL*` suites) and give a `@Suite(.server(...))` a `.timeLimit(.minutes(10))`.
  - **SQLServerVersions:** the SQL Server suites in 8 configurations (2017, 2019, 2022, 2025, and
    2017 at compatibility levels 100, 110, 120 and 130).
- **CI:**
  - **CI (Light)**, pushes to `dev`: UnitTests.
  - **CI (Full)**, pull requests to `main` and by hand: UnitTests, then LabTests against testlab
    over Tailscale.
  - **Nightly**, by hand: SQLServerVersions.

  The lab setup is one action, `.github/actions/lab-tests-setup`; the runner joins the tailnet
  only after every download and stays on it until the job ends. Each run's servers are owned by
  `ci-<run>` or `nightly-<run>` and removed afterwards.
- **Time limits and the watchdog:** a hang fails one test, not the run. XCTest lab tests have 5
  minutes each (the plans' `defaultTestExecutionTimeAllowance`); `MSSQLLabTestCase` allows up to 15
  minutes while the shared server starts and then 2 minutes per test; Swift Testing lab suites have
  `.timeLimit(.minutes(10))`. Every CI test step runs through `.github/scripts/run-test-plan.sh`:
  the job log shows test results and a progress line every five minutes, the full log is uploaded
  with the results, and if nothing finishes for 15 minutes it names the tests still running,
  samples the test processes (`diagnostics/`) and stops the run. It understands both XCTest and
  Swift Testing output; the final totals and the failures (as GitHub error annotations) come from
  the `.xcresult`, not the log.
- **Lost runners:** GitHub's macOS runners sometimes lose contact with GitHub mid-job ("The hosted
  runner lost communication with the server"), which fails the job with no log. On CI the run
  script also starts `.github/scripts/watch-runner.sh`: once a minute it records whether GitHub
  and testlab answer, the tailnet state, free memory, load and the number of finished tests, in
  the job log, in `diagnostics/runner-watch.log` and on testlab in `~/ci-watch/<run>-<attempt>-<name>.log`
  (kept 14 days), so a lost runner still leaves a record. The workflow `rerun-lost-runner.yml`
  reruns the failed jobs of a first attempt of CI (Full) or Nightly Tests once when a job failed
  that way (it runs from `main` only, as GitHub requires). The runner stays on the tailnet until the
  job ends: the watch showed GitHub answering throughout the tests and not at all for minutes
  after `tailscale down`, which is what broke the results uploads.
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
