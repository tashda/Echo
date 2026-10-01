# Test findings

Failures the lab suites turned up that are not mistakes in the tests. Each entry says what fails,
why, and who fixes it, and has a GitHub issue. When a fix lands, delete its entry and close its
issue in the same commit ("Fixes #N"), so this page always lists what is still open. Run one suite with:

```bash
xcodebuild test -project Echo.xcodeproj -scheme Echo -testPlan EchoTests -only-testing:EchoTests/<Suite>
```

(or `test_macos` through XcodeBuildMCP with the same arguments).

Each finding is marked where it fails, so the plans stay green while it is open: an XCTest
`XCTExpectFailure("…: tashda/Echo#N")` (the class runs on the main actor, so failures after an
`await` are matched), or a suite condition naming the issue. An expected failure that no longer
happens fails the test, so a fix shows up at once: remove the marker with the fix.

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

