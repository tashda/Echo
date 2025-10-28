import SwiftUI
import Combine

// MARK: - View Model

@MainActor
final class AgentSidebarViewModel: ObservableObject {
    struct AgentJob: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let lastOutcome: String? }
    struct AgentAlert: Identifiable, Hashable { let id: String; let name: String; let severity: String?; let messageId: String?; let enabled: Bool }
    struct AgentOperator: Identifiable, Hashable { let id: String; let name: String; let email: String?; let enabled: Bool }
    struct AgentProxy: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let credentialName: String? }
    struct AgentErrorLog: Identifiable, Hashable { let id: String; let archiveNumber: Int; let date: String; let size: String? }

    @Published private(set) var jobs: [AgentJob] = []
    @Published private(set) var alerts: [AgentAlert] = []
    @Published private(set) var operators: [AgentOperator] = []
    @Published private(set) var proxies: [AgentProxy] = []
    @Published private(set) var errorLogs: [AgentErrorLog] = []
    @Published private(set) var errorMessage: String?

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
            // Proxies may fail on Linux/without perms; keep list empty and surface error
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func loadErrorLogs(session: ConnectionSession) async {
        do {
            // Agent error logs are log type 2 for xp_enumerrorlogs
            let result = try await session.session.simpleQuery("EXEC xp_enumerrorlogs 2;")
            // Columns vary (Archive #, Date, etc.). Try to derive indices heuristically
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
            // xp_enumerrorlogs may be unavailable to low-priv users; ignore silently
            await MainActor.run { self.errorLogs = [] }
        }
    }

    private func idx(_ result: QueryResultSet, _ name: String) -> Int {
        result.columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0
    }
}

private extension Array where Element == String? {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - View

struct AgentSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var viewModel = AgentSidebarViewModel()
    @State private var searchText: String = ""
    @State private var showNewJobSheet = false
    @State private var newJobName: String = ""
    @State private var newJobDescription: String = ""
    @State private var newJobEnabled: Bool = true

    @State private var expandedJobs = true
    @State private var expandedAlerts = false
    @State private var expandedOperators = false
    @State private var expandedProxies = false
    @State private var expandedErrorLogs = false

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return appModel.sessionManager.sessionForConnection(id)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: .sectionHeaders) {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // Search + New menu
                            HStack(spacing: 8) {
                                TextField("Search jobs", text: $searchText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                                Menu {
                                    Button("New Job…") { showNewJobSheet = true }
                                } label: {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .medium))
                                }
                                .menuStyle(.borderlessButton)
                            }
                            Spacer()
                            Button {
                                if let session = selectedSession {
                                    appModel.openJobManagementTab(for: session)
                                }
                            } label: {
                                Label("Open Job Management", systemImage: "wrench.and.screwdriver")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        group("Jobs", isExpanded: $expandedJobs) {
                            let jobs = viewModel.jobs.filter { searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                            if jobs.isEmpty {
                                placeholder("No jobs found")
                            } else {
                                ForEach(jobs) { job in
                                    HStack(spacing: 8) {
                                        Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                                            .foregroundStyle(job.enabled ? .green : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(job.name).lineLimit(1)
                                            if let outcome = job.lastOutcome {
                                                Text(outcome).font(.caption2).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        group("Alerts", isExpanded: $expandedAlerts) {
                            if viewModel.alerts.isEmpty {
                                placeholder("No alerts found")
                            } else {
                                ForEach(viewModel.alerts) { alert in
                                    HStack(spacing: 8) {
                                        Image(systemName: alert.enabled ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                            .foregroundStyle(alert.enabled ? .yellow : .secondary)
                                        Text(alert.name).lineLimit(1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        group("Operators", isExpanded: $expandedOperators) {
                            if viewModel.operators.isEmpty {
                                placeholder("No operators found")
                            } else {
                                ForEach(viewModel.operators) { op in
                                    HStack(spacing: 8) {
                                        Image(systemName: op.enabled ? "person.fill" : "person")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(op.name).lineLimit(1)
                                            if let email = op.email, !email.isEmpty { Text(email).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        group("Proxies", isExpanded: $expandedProxies) {
                            if viewModel.proxies.isEmpty {
                                placeholder("No proxies found")
                            } else {
                                ForEach(viewModel.proxies) { px in
                                    HStack(spacing: 8) {
                                        Image(systemName: px.enabled ? "shield.fill" : "shield")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(px.name).lineLimit(1)
                                            if let cred = px.credentialName { Text(cred).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        group("Error Logs", isExpanded: $expandedErrorLogs) {
                            if viewModel.errorLogs.isEmpty {
                                placeholder("No error logs visible")
                            } else {
                                ForEach(viewModel.errorLogs) { log in
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Archive #\(log.archiveNumber)")
                                            Text(log.date).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                } header: {
                    AgentSectionHeader(title: "SQL Server Agent")
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .onAppear { Task { await viewModel.reload(for: selectedSession) } }
        .onChange(of: selectedConnectionID) { _, _ in Task { await viewModel.reload(for: selectedSession) } }
        .sheet(isPresented: $showNewJobSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Job").font(.headline)
                TextField("Name", text: $newJobName)
                TextField("Description (optional)", text: $newJobDescription)
                Toggle("Enabled", isOn: $newJobEnabled)
                HStack {
                    Spacer()
                    Button("Cancel") { showNewJobSheet = false }
                    Button("Create") {
                        Task {
                            await createJob()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 360)
        }
    }

    @ViewBuilder
    private func group(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    @ViewBuilder
    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
    }

    private func createJob() async {
        guard let session = selectedSession else { return }
        let name = newJobName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }
        do {
            var sql = "EXEC msdb.dbo.sp_add_job @job_name = N'\(esc(name))', @enabled = \(newJobEnabled ? 1 : 0)"
            if !newJobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql += ", @description = N'\(esc(newJobDescription))'"
            }
            sql += ";"
            _ = try await session.session.simpleQuery(sql)
            // Attach to local server
            let attach = "EXEC msdb.dbo.sp_add_jobserver @job_name = N'\(esc(name))';"
            _ = try? await session.session.simpleQuery(attach)
            // Lookup job_id and open tab
            let lookup = try await session.session.simpleQuery("SELECT CONVERT(nvarchar(36), job_id) AS job_id FROM msdb.dbo.sysjobs WHERE name = N'\(esc(name))'")
            let jobIdIndex = lookup.columns.firstIndex { $0.name.caseInsensitiveCompare("job_id") == .orderedSame } ?? 0
            let id = lookup.rows.first?[safe: jobIdIndex]
            await MainActor.run {
                showNewJobSheet = false
                newJobName = ""; newJobDescription = ""; newJobEnabled = true
                appModel.openJobManagementTab(for: session, selectJobID: id ?? "")
            }
            await viewModel.reload(for: selectedSession)
        } catch {
            // best-effort: just close sheet
            await MainActor.run { showNewJobSheet = false }
        }
    }
}

// MARK: - Section Header (Explorer-like)

private struct AgentSectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
