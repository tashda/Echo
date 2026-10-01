# Echo's tests on the lab

Goal: every Echo test that needs a database server gets it from echo-server-lab through a recipe,
talks to it only through our drivers, and runs the same locally and on GitHub CI. The decisions
below were made by the owner (2026-10-01).

## Where we are

- Four ways to reach a server: `EchoDockerManager` containers, `.ci-fixtures/test-fixtures.env`,
  `TEST_RUNNER_*` variables from `.github/scripts/bootstrap-db-fixtures.sh`, and the lab
  (`EchoTests/Integration/Lab/LabServerSessionTests.swift`, the only test on `.server(...)`).
- About 45 environment variables (`USE_DOCKER`, `ECHO_USE_PACKAGE_FIXTURES`,
  `ECHO_MSSQL_FIXTURE_VALIDATED`, `ECHO_REQUIRE_VALIDATED_FIXTURES`, `ECHO_MSSQL_PORT/VERSION/COMPAT`, ...).
- 60 active test files on `MSSQLDockerTestCase` (34), `PostgresDockerTestCase` (26) and
  `MSSQLDedicatedDockerTestCase`; 27 `.disabled` files (26 Postgres, 1 SQL Server).
- About 240 raw SQL setup statements in tests, and `sqlcmd` through `docker exec` in the base
  classes and the bootstrap script.
- Seven test plans that disagree with each other; no database test has run on CI since March;
  CI Light is red from 4 unit tests.

## Decisions

| Question | Decision |
|---|---|
| How CI reaches the lab | Tailscale in the workflow; testlab advertises itself as a subnet route |
| Server variables | One URL convention (`echo-server-lab/docs/driver-test-convention.md`) |
| The 28 disabled files | Port onto lab recipes |
| Raw SQL setup | Move to recipes or typed APIs as each file migrates |

## Target

- A database test is `@Suite(.server("recipe"))` (from `ServerLabClient`), reads
  `LabServer.current`, and connects through Echo's own `DatabaseSession` factory or the driver.
  Content it only reads comes from the recipe's packs; content it changes is created and removed
  with typed driver APIs. The only SQL text in a test is SQL the test is about (what a user would
  type in the editor).
- Two plans: **UnitTests** (no server; SQLite included, it is a file) and **LabTests** (every
  `.server` suite). `EchoTests.xctestplan` stays as "everything" for local use. The compatibility
  plans go: a version matrix is a list of recipes in the suite (`.server` per version) instead.
- No `EchoDockerManager`, Docker base classes, `.ci-fixtures/`, bootstrap script or `.env`
  reading. The only variables are the lab's own (`SERVERLAB_HOST`, `SERVERLAB_PASSWORD`,
  `SERVERLAB_CLI`).
- Without the lab (an outside contributor) the LabTests plan fails fast with
  `ServerLabError.hostUnreachable`, which says what to check and how to use `SERVERLAB_HOST=local`
  (Docker on the Mac).

## CI

- **CI (Light)**, every push to `dev`: UnitTests on `macos-26`.
- **CI (Full)**, pull requests to `main` and nightly: UnitTests, then LabTests on `macos-26` after
  `tailscale/github-action` joins the tailnet with tag `ci`. The job writes `TESTLAB_SSH_KEY` to
  `~/.ssh/testlab` with a `Host testlab` entry, and `SERVERLAB_PASSWORD` comes from a secret. The
  lab's `serverlab` is built from a pinned echo-server-lab commit (`SERVERLAB_REF`) and cached.
- The self-hosted `echo-test-server` runner and the runner-health workflow are retired once
  LabTests is green on CI.

## Order of work

1. Make UnitTests green (the 4 failing tests) and write the two plans.
2. For each folder (MSSQL, then Postgres, then MySQL and the disabled files): pick or add recipes,
   move the suite to `.server(...)`, replace raw setup with packs or typed APIs (adding the API
   to the driver first when it is missing), and run the suite against the lab.
3. Delete the Docker base classes, `EchoDockerManager`, `.ci-fixtures/` and the bootstrap script
   when nothing uses them.
4. Workflows: Light and Full as above (needs the owner's Tailscale and secret setup).
5. Update the Testing sections of `CLAUDE.md` / `AGENTS.md`.

Every step ends with the suite run against the lab, and no servers of yours left in `serverlab ps`.
