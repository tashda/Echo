import Foundation
import Testing
import SQLServerKit
@testable import Echo

/// Integration tests for SQL Server Agent management operations:
/// alert CRUD, proxy management, category management, and job creation with all subsystems.
/// Uses typed sqlserver-nio APIs per project conventions.
struct MSSQLAgentManagementTests {

    // MARK: - Alert CRUD

    @Test(.tags(.integration))
    func createAndDeleteAlert() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let alertName = "echo_test_alert_\(UUID().uuidString.prefix(8).lowercased())"

        // Create
        try await mssql.agent.createAlert(name: alertName, severity: 17, enabled: true)

        // Verify via list
        let alerts = try await mssql.agent.listAlerts()
        let found = alerts.first { $0.name == alertName }
        #expect(found != nil, "Alert should appear in list after creation")
        #expect(found?.severity == 17)
        #expect(found?.enabled == true)

        // Update
        try await mssql.agent.updateAlert(name: alertName, severity: 19, enabled: false)
        let updatedAlerts = try await mssql.agent.listAlerts()
        let updated = updatedAlerts.first { $0.name == alertName }
        #expect(updated?.severity == 19)
        #expect(updated?.enabled == false)

        // Enable/disable
        try await mssql.agent.enableAlert(name: alertName, enabled: true)
        let enabledAlerts = try await mssql.agent.listAlerts()
        #expect(enabledAlerts.first { $0.name == alertName }?.enabled == true)

        // Delete
        try await mssql.agent.deleteAlert(name: alertName)
        let afterDelete = try await mssql.agent.listAlerts()
        #expect(afterDelete.first { $0.name == alertName } == nil, "Alert should be gone after delete")
    }

    @Test(.tags(.integration))
    func createAlertWithMessageId() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let alertName = "echo_test_msgid_\(UUID().uuidString.prefix(8).lowercased())"

        try await mssql.agent.createAlert(name: alertName, messageId: 50001, databaseName: "master", enabled: true)

        let alerts = try await mssql.agent.listAlerts()
        let found = alerts.first { $0.name == alertName }
        #expect(found?.messageId == 50001)
        #expect(found?.databaseName == "master")

        // Cleanup
        try await mssql.agent.deleteAlert(name: alertName)
    }

    // MARK: - Category CRUD

    @Test(.tags(.integration))
    func createRenameDeleteCategory() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let catName = "echo_test_cat_\(UUID().uuidString.prefix(8).lowercased())"
        let renamedName = catName + "_renamed"

        // Create
        try await mssql.agent.createCategory(name: catName)
        var categories = try await mssql.agent.listCategories()
        #expect(categories.contains { $0.name == catName }, "Category should exist after creation")

        // Rename
        try await mssql.agent.renameCategory(name: catName, newName: renamedName)
        categories = try await mssql.agent.listCategories()
        #expect(categories.contains { $0.name == renamedName }, "Renamed category should exist")
        #expect(!categories.contains { $0.name == catName }, "Old name should be gone")

        // Delete
        try await mssql.agent.deleteCategory(name: renamedName)
        categories = try await mssql.agent.listCategories()
        #expect(!categories.contains { $0.name == renamedName }, "Category should be gone after delete")
    }

    // MARK: - Proxy Management

    @Test(.tags(.integration))
    func listProxies() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        // Just verify the API works without error
        let proxies = try await mssql.agent.listProxies()
        // Proxies may be empty in a test environment — that's fine
        _ = proxies
    }

    // MARK: - Job with All Subsystem Types

    @Test(.tags(.integration))
    func createJobWithVariousSubsystems() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let jobName = "echo_test_subsys_\(UUID().uuidString.prefix(8).lowercased())"

        // Create job
        try await mssql.agent.createJob(named: jobName, description: "Subsystem test job")

        // Add T-SQL step
        try await mssql.agent.addStep(
            jobName: jobName,
            stepName: "TSQL Step",
            subsystem: "TSQL",
            command: "SELECT 1",
            database: "master"
        )

        // Add CmdExec step
        try await mssql.agent.addStep(
            jobName: jobName,
            stepName: "CmdExec Step",
            subsystem: "CmdExec",
            command: "echo hello"
        )

        // Add PowerShell step
        try await mssql.agent.addStep(
            jobName: jobName,
            stepName: "PowerShell Step",
            subsystem: "PowerShell",
            command: "Write-Output 'test'"
        )

        // Verify steps
        let steps = try await mssql.agent.listSteps(jobName: jobName)
        #expect(steps.count == 3, "Should have 3 steps")
        #expect(steps.contains { $0.name == "TSQL Step" })
        #expect(steps.contains { $0.name == "CmdExec Step" })
        #expect(steps.contains { $0.name == "PowerShell Step" })

        // Cleanup
        try await mssql.agent.deleteJob(named: jobName)
    }

    // MARK: - Job Schedule with Active Window

    @Test(.tags(.integration))
    func createScheduleWithActiveWindow() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let jobName = "echo_test_sched_\(UUID().uuidString.prefix(8).lowercased())"
        let scheduleName = "echo_test_sched_daily_\(UUID().uuidString.prefix(8).lowercased())"

        try await mssql.agent.createJob(named: jobName)

        // Create schedule with active window (daily, 9 AM, active between specific dates)
        try await mssql.agent.createSchedule(
            named: scheduleName,
            enabled: true,
            freqType: 4,           // Daily
            freqInterval: 1,       // Every 1 day
            activeStartDate: 20260101,
            activeStartTime: 90000, // 9:00:00
            activeEndDate: 20261231
        )

        try await mssql.agent.attachSchedule(scheduleName: scheduleName, toJob: jobName)

        // Verify
        let schedules = try await mssql.agent.getJobSchedules(jobName: jobName)
        #expect(!schedules.isEmpty, "Job should have a schedule attached")

        // Cleanup
        try await mssql.agent.detachSchedule(scheduleName: scheduleName, fromJob: jobName)
        try await mssql.agent.deleteSchedule(named: scheduleName)
        try await mssql.agent.deleteJob(named: jobName)
    }

    // MARK: - Alert List Contains Extended Fields

    @Test(.tags(.integration))
    func alertInfoIncludesDatabaseAndKeyword() async throws {
        let session = try await MSSQLTestSession.create()
        guard let mssql = session as? MSSQLSession else {
            throw TestSkipError("Not an MSSQL session")
        }
        let alertName = "echo_test_fields_\(UUID().uuidString.prefix(8).lowercased())"

        try await mssql.agent.createAlert(
            name: alertName,
            severity: 20,
            databaseName: "master",
            eventDescriptionKeyword: "deadlock",
            enabled: true
        )

        let alerts = try await mssql.agent.listAlerts()
        let found = alerts.first { $0.name == alertName }
        #expect(found != nil)
        #expect(found?.databaseName == "master")
        #expect(found?.eventDescriptionKeyword == "deadlock")

        try await mssql.agent.deleteAlert(name: alertName)
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var integration: Self
}

// MARK: - Test Helpers

/// Lightweight session factory for Swift Testing integration tests.
/// Uses the same Docker MSSQL instance as MSSQLDockerTestCase.
enum MSSQLTestSession {
    static func create() async throws -> DatabaseSession {
        let port = Int(ProcessInfo.processInfo.environment["TEST_RUNNER_ECHO_MSSQL_PORT"] ?? "14332") ?? 14332
        let password = ProcessInfo.processInfo.environment["TEST_RUNNER_ECHO_MSSQL_PASSWORD"] ?? "YourStrong@Passw0rd"

        let factory = MSSQLNIOFactory()
        return try await factory.connect(
            host: "localhost",
            port: port,
            database: "master",
            tls: false,
            authentication: DatabaseAuthenticationConfiguration(
                method: .sqlPassword,
                username: "sa",
                password: password
            )
        )
    }
}

/// Error used to skip tests when preconditions aren't met.
struct TestSkipError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}
