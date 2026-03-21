import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server Agent operations through raw SQL queries.
///
/// SQL Server Agent may not be available in all environments (e.g., Express edition,
/// containers without agent enabled). Tests wrap operations in do/catch to handle
/// permission or availability failures gracefully.
final class MSSQLAgentTests: MSSQLDockerTestCase {

    // MARK: - Job Listing

    func testListAgentJobs() async throws {
        do {
            let result = try await query("""
                SELECT job_id, name, enabled, date_created
                FROM msdb.dbo.sysjobs
                ORDER BY name
            """)
            // sysjobs should be queryable even if empty
            IntegrationTestHelpers.assertHasColumn(result, named: "name")
            IntegrationTestHelpers.assertHasColumn(result, named: "enabled")
            IntegrationTestHelpers.assertHasColumn(result, named: "date_created")
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
            IntegrationTestHelpers.assertHasColumn(result, named: "category_name")
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
            IntegrationTestHelpers.assertHasColumn(result, named: "job_name")
            IntegrationTestHelpers.assertHasColumn(result, named: "run_status")
            IntegrationTestHelpers.assertHasColumn(result, named: "message")
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
            IntegrationTestHelpers.assertHasColumn(result, named: "job_name")
            IntegrationTestHelpers.assertHasColumn(result, named: "schedule_name")
            IntegrationTestHelpers.assertHasColumn(result, named: "freq_type")
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

        do {
            // Create a test job
            try await execute("EXEC msdb.dbo.sp_add_job @job_name = N'\(jobName)'")

            // Verify it exists
            let result = try await query("""
                SELECT name, enabled FROM msdb.dbo.sysjobs
                WHERE name = '\(jobName)'
            """)
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(
                IntegrationTestHelpers.firstRowValue(result, column: "name"),
                jobName
            )

            // Clean up
            try await execute("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")

            // Verify deletion
            let afterDelete = try await query("""
                SELECT name FROM msdb.dbo.sysjobs WHERE name = '\(jobName)'
            """)
            XCTAssertEqual(afterDelete.rows.count, 0, "Job should be deleted")
        } catch {
            // Attempt cleanup even on failure
            try? await execute("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")
            throw XCTSkip("SQL Agent job operations not available: \(error.localizedDescription)")
        }
    }

    // MARK: - Job Step Management

    func testAddJobStep() async throws {
        let jobName = "echo_test_step_\(UUID().uuidString.prefix(8).lowercased())"

        do {
            try await execute("EXEC msdb.dbo.sp_add_job @job_name = N'\(jobName)'")
            cleanupSQL("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")

            // Add a job step
            try await execute("""
                EXEC msdb.dbo.sp_add_jobstep
                    @job_name = N'\(jobName)',
                    @step_name = N'Test Step 1',
                    @subsystem = N'TSQL',
                    @command = N'SELECT 1',
                    @database_name = N'master'
            """)

            // Verify step exists
            let result = try await query("""
                SELECT js.step_name, js.subsystem, js.command
                FROM msdb.dbo.sysjobsteps js
                JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
                WHERE j.name = '\(jobName)'
            """)
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(
                IntegrationTestHelpers.firstRowValue(result, column: "step_name"),
                "Test Step 1"
            )
        } catch {
            try? await execute("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")
            throw XCTSkip("SQL Agent step operations not available: \(error.localizedDescription)")
        }
    }

    func testAddMultipleJobSteps() async throws {
        let jobName = "echo_test_multi_\(UUID().uuidString.prefix(8).lowercased())"

        do {
            try await execute("EXEC msdb.dbo.sp_add_job @job_name = N'\(jobName)'")
            cleanupSQL("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")

            // Add multiple steps
            for i in 1...3 {
                try await execute("""
                    EXEC msdb.dbo.sp_add_jobstep
                        @job_name = N'\(jobName)',
                        @step_name = N'Step \(i)',
                        @step_id = \(i),
                        @subsystem = N'TSQL',
                        @command = N'SELECT \(i)'
                """)
            }

            let result = try await query("""
                SELECT js.step_id, js.step_name
                FROM msdb.dbo.sysjobsteps js
                JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
                WHERE j.name = '\(jobName)'
                ORDER BY js.step_id
            """)
            IntegrationTestHelpers.assertRowCount(result, expected: 3)
        } catch {
            try? await execute("EXEC msdb.dbo.sp_delete_job @job_name = N'\(jobName)'")
            throw XCTSkip("SQL Agent step operations not available: \(error.localizedDescription)")
        }
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
