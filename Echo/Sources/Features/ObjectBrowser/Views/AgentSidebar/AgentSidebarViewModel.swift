import SwiftUI
import SQLServerKit

@MainActor @Observable
final class AgentSidebarViewModel {
    struct AgentJob: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let lastOutcome: String? }
    struct AgentAlert: Identifiable, Hashable { let id: String; let name: String; let severity: String?; let messageId: String?; let enabled: Bool }
    struct AgentOperator: Identifiable, Hashable { let id: String; let name: String; let email: String?; let enabled: Bool }
    struct AgentProxy: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let credentialName: String? }
    struct AgentErrorLog: Identifiable, Hashable { let id: String; let archiveNumber: Int; let date: String; let size: String? }

    private(set) var jobs: [AgentJob] = []
    private(set) var alerts: [AgentAlert] = []
    private(set) var operators: [AgentOperator] = []
    private(set) var proxies: [AgentProxy] = []
    private(set) var errorLogs: [AgentErrorLog] = []
    private(set) var errorMessage: String?

    func reload(for session: ConnectionSession?) async {
        guard let session, session.connection.databaseType == .microsoftSQL else {
            await MainActor.run {
                self.jobs = []; self.alerts = []; self.operators = []; self.proxies = []; self.errorLogs = []
                self.errorMessage = "Connect to a Microsoft SQL Server to view SQL Server Agent."
            }
            return
        }
        await MainActor.run { self.errorMessage = nil }

        // Preflight: Agent enabled/running?
        do {
            let status = try await session.session.simpleQuery("""
                SELECT
                    is_enabled = CAST(ISNULL(SERVERPROPERTY('IsSqlAgentEnabled'), 0) AS INT),
                    is_running = COALESCE((
                        SELECT TOP (1)
                            CASE WHEN status_desc = 'Running' THEN 1 ELSE 0 END
                        FROM sys.dm_server_services
                        WHERE servicename LIKE 'SQL Server Agent%'
                    ), 0)
            """)
            let enIdx = status.columns.firstIndex { $0.name.caseInsensitiveCompare("is_enabled") == .orderedSame } ?? 0
            let runIdx = status.columns.firstIndex { $0.name.caseInsensitiveCompare("is_running") == .orderedSame } ?? max(0, min(1, status.columns.count - 1))
            let first = status.rows.first ?? []
            let en = (first[safe: enIdx] ?? "0") == "1"
            let rn = (first[safe: runIdx] ?? "0") == "1"
            if !(en && rn) {
                await MainActor.run { self.errorMessage = "SQL Server Agent is not running or Agent XPs are disabled." }
            }
        } catch {
            // Ignore preflight errors; proceed best-effort
        }

        async let loadJobs: Void = loadJobs(session: session)
        async let loadAlerts: Void = loadAlerts(session: session)
        async let loadOps: Void = loadOperators(session: session)
        async let loadProxies: Void = loadProxies(session: session)
        async let loadErrLogs: Void = loadErrorLogs(session: session)
        _ = await (loadJobs, loadAlerts, loadOps, loadProxies, loadErrLogs)
    }

    private func loadJobs(session: ConnectionSession) async {
        do {
            let sql = """
            SELECT
                j.name,
                j.enabled,
                last_run_outcome = CASE h.run_status
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Canceled'
                    WHEN 4 THEN 'In Progress'
                    ELSE NULL
                END
            FROM msdb.dbo.sysjobs AS j
            OUTER APPLY (
                SELECT TOP (1) run_status
                FROM msdb.dbo.sysjobhistory AS h
                WHERE h.job_id = j.job_id
                ORDER BY h.instance_id DESC
            ) AS h
            ORDER BY j.name;
            """
            let result = try await session.session.simpleQuery(sql)
            let nameIdx = result.columns.firstIndex { $0.name.caseInsensitiveCompare("name") == .orderedSame } ?? 0
            let enabledIdx = result.columns.firstIndex { $0.name.caseInsensitiveCompare("enabled") == .orderedSame } ?? max(0, min(1, result.columns.count - 1))
            let outcomeIdx = result.columns.firstIndex { $0.name.caseInsensitiveCompare("last_run_outcome") == .orderedSame }
            let items: [AgentJob] = result.rows.compactMap { row in
                guard let name = row[safe: nameIdx] ?? nil else { return nil }
                let enabled = ((row[safe: enabledIdx] ?? "0") == "1")
                let outcome = outcomeIdx.flatMap { row[safe: $0] ?? nil }
                return AgentJob(id: name, name: name, enabled: enabled, lastOutcome: outcome)
            }
            await MainActor.run { self.jobs = items }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadAlerts(session: ConnectionSession) async {
        do {
            let sql = "SELECT name, severity, message_id, enabled FROM msdb.dbo.sysalerts ORDER BY name;"
            let result = try await session.session.simpleQuery(sql)
            let n = idx(result, "name"); let sev = idx(result, "severity"); let mid = idx(result, "message_id"); let en = idx(result, "enabled")
            let items: [AgentAlert] = result.rows.compactMap { row in
                guard let name = row[safe: n] ?? nil else { return nil }
                return AgentAlert(id: name, name: name, severity: row[safe: sev] ?? nil, messageId: row[safe: mid] ?? nil, enabled: (row[safe: en] ?? "0") == "1")
            }
            await MainActor.run { self.alerts = items }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadOperators(session: ConnectionSession) async {
        do {
            let sql = "SELECT name, email_address, enabled FROM msdb.dbo.sysoperators ORDER BY name;"
            let result = try await session.session.simpleQuery(sql)
            let n = idx(result, "name"); let em = idx(result, "email_address"); let en = idx(result, "enabled")
            let items: [AgentOperator] = result.rows.compactMap { row in
                guard let name = row[safe: n] ?? nil else { return nil }
                return AgentOperator(id: name, name: name, email: row[safe: em] ?? nil, enabled: (row[safe: en] ?? "0") == "1")
            }
            await MainActor.run { self.operators = items }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadProxies(session: ConnectionSession) async {
        do {
            let sql = """
            SELECT p.name, p.enabled, c.name AS credential_name
            FROM msdb.dbo.sysproxies AS p
            LEFT JOIN sys.credentials AS c ON p.credential_id = c.credential_id
            ORDER BY p.name;
            """
            let result = try await session.session.simpleQuery(sql)
            let n = idx(result, "name"); let en = idx(result, "enabled"); let cred = idx(result, "credential_name")
            let items: [AgentProxy] = result.rows.compactMap { row in
                guard let name = row[safe: n] ?? nil else { return nil }
                return AgentProxy(id: name, name: name, enabled: (row[safe: en] ?? "0") == "1", credentialName: row[safe: cred] ?? nil)
            }
            await MainActor.run { self.proxies = items }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadErrorLogs(session: ConnectionSession) async {
        do {
            let result = try await session.session.simpleQuery("EXEC xp_enumerrorlogs 2;")
            let archiveIdx = result.columns.firstIndex { $0.name.localizedCaseInsensitiveContains("archive") } ?? 0
            let dateIdx = result.columns.firstIndex { $0.name.localizedCaseInsensitiveContains("date") } ?? min(1, max(0, result.columns.count - 1))
            let sizeIdx = result.columns.firstIndex { $0.name.localizedCaseInsensitiveContains("size") }
            let items: [AgentErrorLog] = result.rows.compactMap { row in
                let archiveStr: String = row.indices.contains(archiveIdx) ? (row[archiveIdx] ?? "0") : "0"
                let digitsOnly = archiveStr.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
                let archive = Int(String(String.UnicodeScalarView(digitsOnly))) ?? 0
                let date: String = row.indices.contains(dateIdx) ? (row[dateIdx] ?? "") : ""
                let size: String? = sizeIdx.flatMap { idx in
                    row.indices.contains(idx) ? (row[idx] ?? nil) : nil
                }
                return AgentErrorLog(id: "\(archive)", archiveNumber: archive, date: date, size: size)
            }
            await MainActor.run { self.errorLogs = items }
        } catch {
            await MainActor.run { self.errorLogs = [] }
        }
    }

    private func idx(_ result: QueryResultSet, _ name: String) -> Int {
        result.columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0
    }
}

