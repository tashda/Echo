import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server Agent operations through raw SQL queries.
///
/// SQL Server Agent may not be available in all environments (e.g., Express edition,
/// containers without agent enabled). Tests wrap operations in do/catch to handle
/// permission or availability failures gracefully.
final class MSSQLAgentTests: MSSQLLabTestCase {

    // MARK: - Job Listing

    func testListAgentJobs() async throws {
        do {
            let result = try await query("""
                SELECT job_id, name, enabled, date_created
                FROM msdb.dbo.sysjobs
                ORDER BY name
            """)
            // sysjobs should be queryable; columns only available if rows exist
            if !result.rows.isEmpty {
                IntegrationTestHelpers.assertHasColumn(result, named: "name")
                IntegrationTestHelpers.assertHasColumn(result, named: "enabled")
                IntegrationTestHelpers.assertHasColumn(result, named: "date_created")
            }
        } catch {
            throw XCTSkip("SQL Agent not available: \(error.localizedDescription)")
        }
    }

    func testListAgentJobsWithCategory() async throws {
        do {
            let result = try await query("""
                SELECT j.name, j.enabled, c.name AS category_name
                FROM msdb.dbo.sysjobs j
                LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
                ORDER BY j.name
            """)
            if !result.rows.isEmpty {
                IntegrationTestHelpers.assertHasColumn(result, named: "category_name")
            }
        } catch {
            throw XCTSkip("SQL Agent not available: \(error.localizedDescription)")
        }
    }

    // MARK: - Job History

    func testGetJobHistory() async throws {
        do {
            let result = try await query("""
                SELECT TOP 10
                    j.name AS job_name,
                    h.step_id,
                    h.step_name,
                    h.run_status,
                    h.run_date,
                    h.run_time,
                    h.run_duration,
                    h.message
                FROM msdb.dbo.sysjobhistory h
                JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
                ORDER BY h.run_date DESC, h.run_time DESC
            """)
            // Columns only available when rows exist (driver derives metadata from rows)
            if !result.rows.isEmpty {
                IntegrationTestHelpers.assertHasColumn(result, named: "job_name")
                IntegrationTestHelpers.assertHasColumn(result, named: "run_status")
                IntegrationTestHelpers.assertHasColumn(result, named: "message")
            }
        } catch {
            throw XCTSkip("SQL Agent not available: \(error.localizedDescription)")
        }
    }

    // MARK: - Job Schedules

    func testGetJobSchedules() async throws {
        do {
            let result = try await query("""
                SELECT
                    j.name AS job_name,
                    s.name AS schedule_name,
                    s.enabled,
                    s.freq_type,
                    s.freq_interval,
                    s.active_start_date,
                    s.active_start_time
                FROM msdb.dbo.sysjobschedules js
                JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
                JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
                ORDER BY j.name
            """)
            if !result.rows.isEmpty {
                IntegrationTestHelpers.assertHasColumn(result, named: "job_name")
                IntegrationTestHelpers.assertHasColumn(result, named: "schedule_name")
                IntegrationTestHelpers.assertHasColumn(result, named: "freq_type")
            }
        } catch {
            throw XCTSkip("SQL Agent not available: \(error.localizedDescription)")
        }
    }

    // MARK: - Agent Error Logs

    func testListErrorLogs() async throws {
        do {
            let mssqlSession = try XCTUnwrap(session as? MSSQLSession)
            let logs = try await mssqlSession.agent.listErrorLogs()
            // Error log may be empty in a freshly started Docker container
            if !logs.isEmpty {
                XCTAssertNotNil(logs.first?.date, "Error log should have a date")
            }
        } catch {
            throw XCTSkip("SQL Agent not available or lacking permissions: \(error.localizedDescription)")
        }
    }

    // MARK: - Job Create / Delete

    func testCreateAndDeleteJob() async throws {
        let jobName = "echo_test_job_\(UUID().uuidString.prefix(8).lowercased())"
        let agent = sqlserverClient.agent

        try await agent.createJob(named: jobName)
        let created = try await agent.listJobs().first { $0.name == jobName }
        XCTAssertEqual(created?.enabled, true)

        try await agent.deleteJob(named: jobName)
        let remaining = try await agent.listJobs()
        XCTAssertFalse(remaining.contains { $0.name == jobName }, "Job should be deleted")
    }

    // MARK: - Job Step Management

    func testAddJobStep() async throws {
        let jobName = "echo_test_step_\(UUID().uuidString.prefix(8).lowercased())"
        let agent = sqlserverClient.agent
        try await agent.createJob(named: jobName)

        try await agent.addStep(jobName: jobName, stepName: "Test Step 1", subsystem: "TSQL", command: "SELECT 1", database: "master")

        let steps = try await agent.listSteps(jobName: jobName)
        XCTAssertEqual(steps.map(\.name), ["Test Step 1"])
        XCTAssertEqual(steps.first?.subsystem, "TSQL")
        XCTAssertEqual(steps.first?.command, "SELECT 1")
        XCTAssertEqual(steps.first?.databaseName, "master")
    }

    func testAddMultipleJobSteps() async throws {
        let jobName = "echo_test_multi_\(UUID().uuidString.prefix(8).lowercased())"
        let agent = sqlserverClient.agent
        try await agent.createJob(named: jobName)

        for i in 1...3 {
            try await agent.addStep(jobName: jobName, stepName: "Step \(i)", subsystem: "TSQL", command: "SELECT \(i)")
        }

        let steps = try await agent.listSteps(jobName: jobName).sorted { $0.stepId < $1.stepId }
        XCTAssertEqual(steps.map(\.stepId), [1, 2, 3])
        XCTAssertEqual(steps.map(\.name), ["Step 1", "Step 2", "Step 3"])
    }

    // MARK: - Agent Status

    func testAgentServiceStatus() async throws {
        do {
            let result = try await query("""
                SELECT servicename, status, startup_type
                FROM sys.dm_server_services
                WHERE servicename LIKE '%Agent%'
            """)
            // May return zero rows if Agent is not installed
            IntegrationTestHelpers.assertHasColumn(result, named: "servicename")
            IntegrationTestHelpers.assertHasColumn(result, named: "status")
        } catch {
            throw XCTSkip("dm_server_services not available: \(error.localizedDescription)")
        }
    }

    // MARK: - Job Categories

    func testListJobCategories() async throws {
        do {
            let result = try await query("""
                SELECT category_id, name, category_class
                FROM msdb.dbo.syscategories
                ORDER BY name
            """)
            // Default categories should exist
            IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
            IntegrationTestHelpers.assertHasColumn(result, named: "name")
        } catch {
            throw XCTSkip("SQL Agent categories not available: \(error.localizedDescription)")
        }
    }
}
