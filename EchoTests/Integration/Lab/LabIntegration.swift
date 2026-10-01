import Foundation
import Testing

/// Suites on echo-server-lab servers (`.server("recipe")`) run only when this is set. The EchoTests
/// plan sets it; the UnitTests plan does not, so it runs without a lab.
let labIntegrationEnabled = ProcessInfo.processInfo.environment["SERVERLAB_INTEGRATION"] == "1"

let labIntegrationNote: Comment = "Needs echo-server-lab: run the EchoTests plan, or set SERVERLAB_INTEGRATION=1"

/// Recipes of the servers the XCTest suites share (`LabSharedServers`).
enum LabRecipes {
    static let postgres = "pg-17-empty"
    static let mysql = "mysql-8.4-empty"

    /// The SQL Server version the SQL Server suites run on: `ECHO_LAB_SQLSERVER_VERSION` (2017,
    /// 2019, 2022 or 2025; the SQLServerVersions plan sets it per configuration), else 2022.
    static let sqlServerVersion = ProcessInfo.processInfo.environment["ECHO_LAB_SQLSERVER_VERSION"] ?? "2022"
    /// SQL Server with Agent on and nothing added.
    static var sqlServer: String { "mssql-\(sqlServerVersion)-agent" }
    /// SQL Server with AdventureWorks, AdventureWorksLT and AdventureWorksDW.
    static var sqlServerSamples: String { "mssql-\(sqlServerVersion)-adventureworks" }
}
