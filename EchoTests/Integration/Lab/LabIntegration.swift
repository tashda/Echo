import Foundation
import Testing

/// Suites on echo-server-lab servers (`.server("recipe")`) run only when this is set. The EchoTests
/// plan sets it; the UnitTests plan does not, so it runs without a lab.
let labIntegrationEnabled = ProcessInfo.processInfo.environment["SERVERLAB_INTEGRATION"] == "1"

let labIntegrationNote: Comment = "Needs echo-server-lab: run the EchoTests plan, or set SERVERLAB_INTEGRATION=1"

/// Recipes of the servers the XCTest suites share (`LabSharedServers`).
enum LabRecipes {
    static let postgres = "pg-17-empty"
}
