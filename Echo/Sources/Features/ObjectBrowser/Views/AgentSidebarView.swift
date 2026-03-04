import SwiftUI
import Combine
import SQLServerKit

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
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @EnvironmentObject private var environmentState: EnvironmentState
    
    @StateObject private var viewModel = AgentSidebarViewModel()
    @State private var searchText: String = ""
    @State private var showNewJobSheet = false
    @State private var newJobName: String = ""
    @State private var newJobDescription: String = ""
    @State private var newJobEnabled: Bool = true
    @State private var newJobOwner: String = ""
    @State private var newJobCategory: String = ""
    // Optional initial step (legacy simple mode)
    @State private var newStepName: String = "Step 1"
    @State private var newStepDatabase: String = ""
    @State private var newStepCommand: String = ""
    // Optional schedule (legacy simple mode)
    @State private var addDailySchedule: Bool = false
    @State private var scheduleName: String = "Daily"
    @State private var scheduleEnabled: Bool = true
    @State private var scheduleStartHHMMSS: String = "090000"
    @State private var scheduleInterval: String = "1" // days
    // Wizard state (multi-step, multi-schedule, notifications)
    enum SubsystemChoice: String, CaseIterable, Identifiable { case tsql = "T-SQL", cmdExec = "CmdExec", powershell = "PowerShell"; var id: String { rawValue } }
    struct WizardStep: Identifiable, Hashable {
        var id = UUID()
        var name: String = "Step"
        var subsystem: SubsystemChoice = .tsql
        var database: String = ""
        var command: String = ""
        var proxyName: String = ""
        var outputFile: String = ""
        var appendOutput: Bool = false
        var onSuccess: StepActionChoice = .goToNext
        var onFail: StepActionChoice = .quitFailure
        var onSuccessGoTo: Int = 1
        var onFailGoTo: Int = 1
        var retryAttempts: Int = 0
        var retryInterval: Int = 0
    }
    enum StepActionChoice: String, CaseIterable, Identifiable { case quitSuccess = "Quit success", quitFailure = "Quit failure", goToNext = "Go to next", goToStep = "Go to step"; var id: String { rawValue } }
    @State private var wizardSteps: [WizardStep] = []
    @State private var startStepId: Int? = nil
    struct WizardSchedule: Identifiable, Hashable {
        var id = UUID()
        var name: String = "Daily"
        var enabled: Bool = true
        var mode: ScheduleMode = .daily
        var startHHMMSS: String = "090000"
        var endHHMMSS: String = ""
        var startDateYYYYMMDD: String = ""
        var endDateYYYYMMDD: String = ""
        var subdayUnit: Int = 0 // 0=none, 4=minutes, 8=hours
        var subdayInterval: Int = 0
        var everyDays: Int = 1
        var weeklyEveryWeeks: Int = 1
        var weeklyDays: Set<WeeklyDayChoice> = []
    }
    enum ScheduleMode: String, CaseIterable, Identifiable { case daily = "Daily", weekly = "Weekly", monthly = "Monthly", monthlyRelative = "Monthly (relative)", once = "One time"; var id: String { rawValue } }
    enum MonthWeekChoice: String, CaseIterable, Identifiable { case first="First", second="Second", third="Third", fourth="Fourth", last="Last"; var id: String { rawValue } }
    @State private var startAfterCreate: Bool = false
    enum WeeklyDayChoice: String, CaseIterable, Identifiable { case sunday="Sun", monday="Mon", tuesday="Tue", wednesday="Wed", thursday="Thu", friday="Fri", saturday="Sat"; var id: String { rawValue } }
    @State private var wizardSchedules: [WizardSchedule] = []
    enum NotifyLevel: String, CaseIterable, Identifiable { case none="None", success="On success", failure="On failure", completion="On completion"; var id: String { rawValue } }
    @State private var notifyOperatorName: String = ""
    @State private var notifyLevel: NotifyLevel = .none
    // Error feedback
    @State private var newJobError: String? = nil

    @State private var expandedJobs = true
    @State private var expandedAlerts = false
    @State private var expandedOperators = false
    @State private var expandedProxies = false
    @State private var expandedErrorLogs = false

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionManager.sessionForConnection(id)
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
                                    environmentState.openJobManagementTab(for: session)
                                }
                            } label: {
                                Label("Open Job Management", systemImage: "wrench.and.screwdriver")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        agentGroups
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
            newJobSheetContent
        }
    }

    @ViewBuilder
    private var agentGroups: some View {
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

    @ViewBuilder
    private var newJobSheetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New SQL Server Agent Job").font(.headline)
            if let err = newJobError, !err.isEmpty { Text(err).font(.footnote).foregroundStyle(.red) }
            TabView {
                // General
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name", text: $newJobName)
                    TextField("Description (optional)", text: $newJobDescription)
                    Toggle("Enabled", isOn: $newJobEnabled)
                    Toggle("Start job after creation", isOn: $startAfterCreate)
                    Divider()
                    Text("Owner and Category").font(.subheadline)
                    TextField("Owner (default current login)", text: $newJobOwner)
                    TextField("Category (optional)", text: $newJobCategory)
                }
                .tabItem { Text("General") }

                // Steps
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(wizardSteps.enumerated()), id: \.element.id) { index, step in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { TextField("Step name", text: $wizardSteps[index].name); Picker("Subsystem", selection: $wizardSteps[index].subsystem) { ForEach(SubsystemChoice.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 180) }
                                    if step.subsystem == .tsql { TextField("Database", text: $wizardSteps[index].database) }
                                    TextField("Command", text: $wizardSteps[index].command, axis: .vertical).lineLimit(2...5)
                                    HStack { TextField("Run As (Proxy)", text: $wizardSteps[index].proxyName); TextField("Output file", text: $wizardSteps[index].outputFile); Toggle("Append", isOn: $wizardSteps[index].appendOutput) }
                                    HStack { Picker("On success", selection: $wizardSteps[index].onSuccess) { ForEach(StepActionChoice.allCases) { Text($0.rawValue).tag($0) } } ; if step.onSuccess == .goToStep { TextField("Step ID", value: $wizardSteps[index].onSuccessGoTo, formatter: NumberFormatter()).frame(width: 80) } }
                                    HStack { Picker("On failure", selection: $wizardSteps[index].onFail) { ForEach(StepActionChoice.allCases) { Text($0.rawValue).tag($0) } } ; if step.onFail == .goToStep { TextField("Step ID", value: $wizardSteps[index].onFailGoTo, formatter: NumberFormatter()).frame(width: 80) } }
                                    HStack { TextField("Retry attempts", value: $wizardSteps[index].retryAttempts, formatter: NumberFormatter()).frame(width: 120); TextField("Retry interval (min)", value: $wizardSteps[index].retryInterval, formatter: NumberFormatter()).frame(width: 160) }
                                    HStack { Button("Remove", role: .destructive) { wizardSteps.remove(at: index); if let sid = startStepId, sid > wizardSteps.count { startStepId = wizardSteps.count } } ; Spacer() }
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                    HStack { Button("Add step") { wizardSteps.append(WizardStep(name: "Step \(wizardSteps.count+1)")) } ; Spacer() }
                    HStack { Text("Start step ID: "); TextField("", value: Binding(get: { startStepId ?? 1 }, set: { startStepId = $0 }), formatter: NumberFormatter()).frame(width: 60) }
                }
                .tabItem { Text("Steps") }

                // Schedules
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(wizardSchedules.enumerated()), id: \.element.id) { index, sch in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { TextField("Name", text: $wizardSchedules[index].name); Toggle("Enabled", isOn: $wizardSchedules[index].enabled) }
                                    Picker("Mode", selection: $wizardSchedules[index].mode) { ForEach(ScheduleMode.allCases) { Text($0.rawValue).tag($0) } }
                                    HStack { TextField("Start time (HHMMSS)", text: $wizardSchedules[index].startHHMMSS).frame(width: 120); TextField("End time (HHMMSS)", text: $wizardSchedules[index].endHHMMSS).frame(width: 120) }
                                    HStack { TextField("Start date (YYYYMMDD)", text: $wizardSchedules[index].startDateYYYYMMDD).frame(width: 150); TextField("End date (YYYYMMDD)", text: $wizardSchedules[index].endDateYYYYMMDD).frame(width: 150) }
                                    if wizardSchedules[index].mode == .daily {
                                        HStack { Text("Every"); TextField("Days", value: $wizardSchedules[index].everyDays, formatter: NumberFormatter()).frame(width: 60); Text("days") }
                                    } else if wizardSchedules[index].mode == .weekly {
                                        HStack { Text("Every"); TextField("Weeks", value: $wizardSchedules[index].weeklyEveryWeeks, formatter: NumberFormatter()).frame(width: 60); Text("weeks on:") }
                                        HStack { ForEach(WeeklyDayChoice.allCases) { day in Toggle(day.rawValue, isOn: Binding(get: { wizardSchedules[index].weeklyDays.contains(day) }, set: { checked in if checked { wizardSchedules[index].weeklyDays.insert(day) } else { wizardSchedules[index].weeklyDays.remove(day) } })) } }
                                    } else if wizardSchedules[index].mode == .monthly {
                                        HStack { Text("Day"); TextField("", value: $wizardSchedules[index].everyDays, formatter: NumberFormatter()).frame(width: 60); Text("of every"); TextField("", value: $wizardSchedules[index].weeklyEveryWeeks, formatter: NumberFormatter()).frame(width: 60); Text("month(s)") }
                                    } else if wizardSchedules[index].mode == .monthlyRelative {
                                        HStack { Picker("Week", selection: $wizardSchedules[index].weeklyEveryWeeks) { Text("First").tag(1); Text("Second").tag(2); Text("Third").tag(3); Text("Fourth").tag(4); Text("Last").tag(5) } ; Picker("Day", selection: Binding(get: { wizardSchedules[index].weeklyDays.first ?? .monday }, set: { wizardSchedules[index].weeklyDays = [$0] })) { ForEach(WeeklyDayChoice.allCases) { Text($0.rawValue).tag($0) } } ; Text("of every"); TextField("", value: $wizardSchedules[index].everyDays, formatter: NumberFormatter()).frame(width: 60); Text("month(s)") }
                                    }
                                    Divider()
                                    Text("Subday frequency").font(.subheadline)
                                    HStack { Text("Occurs every"); TextField("", value: $wizardSchedules[index].subdayInterval, formatter: NumberFormatter()).frame(width: 80); Picker("", selection: $wizardSchedules[index].subdayUnit) { Text("(none)").tag(0); Text("Minutes").tag(4); Text("Hours").tag(8) }.pickerStyle(.segmented).frame(width: 240) }
                                    HStack { Button("Remove", role: .destructive) { wizardSchedules.remove(at: index) } ; Spacer() }
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                    HStack { Button("Add schedule") { wizardSchedules.append(WizardSchedule()) } ; Spacer() }
                }
                .tabItem { Text("Schedules") }

                // Notifications
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Operator name", text: $notifyOperatorName)
                    Picker("Notify", selection: $notifyLevel) { ForEach(NotifyLevel.allCases) { Text($0.rawValue).tag($0) } }
                }
                .tabItem { Text("Notifications") }
            }
            HStack { Spacer(); Button("Cancel") { showNewJobSheet = false }; Button("Create") { Task { await createJobWithBuilder() } }.keyboardShortcut(.defaultAction) }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            // Default owner to current login if blank
            if newJobOwner.isEmpty, let session = selectedSession {
                Task {
                    do {
                        let rs = try await session.session.simpleQuery("SELECT SUSER_SNAME() AS name;")
                        let idx = rs.columns.firstIndex { $0.name.caseInsensitiveCompare("name") == .orderedSame } ?? 0
                        let val = rs.rows.first?[safe: idx] ?? ""
                        await MainActor.run { newJobOwner = val ?? "" }
                    } catch { /* ignore */ }
                }
            }
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

    // New builder-based creation path (uses wizard when provided, falls back to simple fields)
    private func createJobWithBuilder() async {
        guard let session = selectedSession else { return }
        let name = newJobName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { newJobError = "Job name is required"; return }
        newJobError = nil
        // Preflight Agent
        do {
            let status = try await session.session.simpleQuery("""
                SELECT CAST(ISNULL(SERVERPROPERTY('IsSqlAgentEnabled'),0) AS INT) AS is_enabled,
                       COALESCE((SELECT TOP (1) CASE WHEN status_desc='Running' THEN 1 ELSE 0 END FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server Agent%'),0) AS is_running
            """)
            let enIdx = status.columns.firstIndex { $0.name.caseInsensitiveCompare("is_enabled") == .orderedSame } ?? 0
            let rnIdx = status.columns.firstIndex { $0.name.caseInsensitiveCompare("is_running") == .orderedSame } ?? 1
            let row = status.rows.first ?? []
            let enabled = (row[safe: enIdx] ?? "0") == "1"
            let running = (row[safe: rnIdx] ?? "0") == "1"
            if !(enabled && running) { newJobError = "SQL Server Agent is not running or Agent XPs are disabled."; return }
        } catch { newJobError = error.localizedDescription; return }

        do {
            guard let mssql = session.session as? MSSQLSession else { throw NSError(domain: "Agent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Active session is not SQL Server"]) }
            let agent = mssql.makeAgentClient()
            var builder = SQLServerAgentJobBuilder(agent: agent, jobName: name,
                                                   description: newJobDescription.isEmpty ? nil : newJobDescription,
                                                   enabled: newJobEnabled,
                                                   ownerLoginName: newJobOwner.isEmpty ? nil : newJobOwner,
                                                   categoryName: newJobCategory.isEmpty ? nil : newJobCategory,
                                                   autoAttachServer: true)
            if !wizardSteps.isEmpty {
                for (index, s) in wizardSteps.enumerated() {
                    let subsystem: SQLServerAgentJobStep.Subsystem = (s.subsystem == .tsql ? .tsql : s.subsystem == .cmdExec ? .cmdExec : .powershell)
                    var step = SQLServerAgentJobStep(name: s.name.isEmpty ? "Step \(index+1)" : s.name, subsystem: subsystem, command: s.command, database: s.subsystem == .tsql ? (s.database.isEmpty ? nil : s.database) : nil)
                    if !s.proxyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { step.proxyName = s.proxyName }
                    if !s.outputFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { step.outputFile = s.outputFile; step.appendOutputFile = s.appendOutput }
                    // Flow mapping
                    switch s.onSuccess { case .goToStep: step.onSuccess = .goToStep(s.onSuccessGoTo); case .goToNext: step.onSuccess = .goToNextStep; case .quitSuccess: step.onSuccess = .quitWithSuccess; case .quitFailure: step.onSuccess = .quitWithFailure }
                    switch s.onFail { case .goToStep: step.onFail = .goToStep(s.onFailGoTo); case .goToNext: step.onFail = .goToNextStep; case .quitSuccess: step.onFail = .quitWithSuccess; case .quitFailure: step.onFail = .quitWithFailure }
                    if s.retryAttempts > 0 { step.retryAttempts = s.retryAttempts }
                    if s.retryInterval > 0 { step.retryIntervalMinutes = s.retryInterval }
                    builder = builder.addStep(step)
                }
                if let sid = startStepId { builder = builder.setStartStepId(sid) }
            } else {
                // Simple, single-step mode
                let cmd = newStepCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cmd.isEmpty {
                    let step = SQLServerAgentJobStep(name: newStepName.isEmpty ? "Step 1" : newStepName, subsystem: .tsql, command: cmd, database: newStepDatabase.isEmpty ? nil : newStepDatabase)
                    builder = builder.addStep(step).setStartStepId(1)
                }
            }
            if !wizardSchedules.isEmpty {
                let map: [WeeklyDayChoice: SQLServerAgentJobSchedule.WeeklyDay] = [.sunday:.sunday,.monday:.monday,.tuesday:.tuesday,.wednesday:.wednesday,.thursday:.thursday,.friday:.friday,.saturday:.saturday]
                for sch in wizardSchedules {
                    let st = Int(sch.startHHMMSS.filter({ $0.isNumber })) ?? 90000
                    let et = Int(sch.endHHMMSS.filter({ $0.isNumber }))
                    let sd = Int(sch.startDateYYYYMMDD.filter({ $0.isNumber }))
                    let ed = Int(sch.endDateYYYYMMDD.filter({ $0.isNumber }))
                    switch sch.mode {
                    case .daily:
                        builder = builder.addSchedule(SQLServerAgentJobSchedule(name: sch.name, enabled: sch.enabled, kind: .daily(everyDays: max(1, sch.everyDays), startTime: st), activeStartDate: sd, activeEndDate: ed, activeStartTime: st, activeEndTime: et, subdayType: sch.subdayUnit == 0 ? nil : sch.subdayUnit, subdayInterval: sch.subdayUnit == 0 ? nil : max(1, sch.subdayInterval)))
                    case .monthly:
                        builder = builder.addSchedule(SQLServerAgentJobSchedule(name: sch.name, enabled: sch.enabled, kind: .monthly(day: max(1, min(sch.everyDays, 31)), everyMonths: max(1, sch.weeklyEveryWeeks), startTime: st), activeStartDate: sd, activeEndDate: ed, activeStartTime: st, activeEndTime: et, subdayType: sch.subdayUnit == 0 ? nil : sch.subdayUnit, subdayInterval: sch.subdayUnit == 0 ? nil : max(1, sch.subdayInterval)))
                    case .monthlyRelative:
                        let weekMap: [Int: SQLServerAgentJobSchedule.MonthWeek] = [1:.first,2:.second,3:.third,4:.fourth,5:.last]
                        let wk = weekMap[sch.weeklyEveryWeeks] ?? .first
                        let day = map[sch.weeklyDays.first ?? .monday] ?? .monday
                        builder = builder.addSchedule(SQLServerAgentJobSchedule(name: sch.name, enabled: sch.enabled, kind: .monthlyRelative(week: wk, day: day, everyMonths: max(1, sch.everyDays), startTime: st), activeStartDate: sd, activeEndDate: ed, activeStartTime: st, activeEndTime: et, subdayType: sch.subdayUnit == 0 ? nil : sch.subdayUnit, subdayInterval: sch.subdayUnit == 0 ? nil : max(1, sch.subdayInterval)))
                    case .once:
                        let today = Calendar(identifier: .gregorian).dateComponents([.year,.month,.day], from: Date())
                        let dateInt = (today.year ?? 1970)*10000 + (today.month ?? 1)*100 + (today.day ?? 1)
                        builder = builder.addSchedule(SQLServerAgentJobSchedule(name: sch.name, enabled: sch.enabled, kind: .oneTime(startDate: dateInt, startTime: st), activeStartDate: sd ?? dateInt, activeEndDate: ed, activeStartTime: st, activeEndTime: et, subdayType: sch.subdayUnit == 0 ? nil : sch.subdayUnit, subdayInterval: sch.subdayUnit == 0 ? nil : max(1, sch.subdayInterval)))
                    case .weekly:
                        let days = sch.weeklyDays.compactMap { map[$0] }
                        builder = builder.addSchedule(SQLServerAgentJobSchedule(name: sch.name, enabled: sch.enabled, kind: .weekly(days: days, everyWeeks: max(1, sch.weeklyEveryWeeks), startTime: st), activeStartDate: sd, activeEndDate: ed, activeStartTime: st, activeEndTime: et, subdayType: sch.subdayUnit == 0 ? nil : sch.subdayUnit, subdayInterval: sch.subdayUnit == 0 ? nil : max(1, sch.subdayInterval)))
                    }
                }
            } else if addDailySchedule {
                let startTime = Int(scheduleStartHHMMSS.filter({ $0.isNumber })) ?? 90000
                let interval = Int(scheduleInterval) ?? 1
                let schedName = scheduleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Daily" : scheduleName
                builder = builder.addSchedule(SQLServerAgentJobSchedule(name: schedName, enabled: scheduleEnabled, kind: .daily(everyDays: max(1, interval), startTime: startTime)))
            }
            if !notifyOperatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lvl: SQLServerAgentJobNotification.Level = (notifyLevel == .success ? .onSuccess : notifyLevel == .failure ? .onFailure : notifyLevel == .completion ? .onCompletion : .none)
                builder = builder.setNotification(SQLServerAgentJobNotification(operatorName: notifyOperatorName, level: lvl))
            }
            let (_, jobId) = try await builder.commit()
            if startAfterCreate {
                _ = try? await mssql.makeAgentClient().startJob(named: name)
            }
            await MainActor.run {
                showNewJobSheet = false
                resetWizardState()
                environmentState.openJobManagementTab(for: session, selectJobID: jobId ?? "")
            }
            await viewModel.reload(for: selectedSession)
        } catch {
            await MainActor.run { newJobError = String(describing: error) }
        }
    }

    private func resetWizardState() {
        newJobName = ""; newJobDescription = ""; newJobEnabled = true
        newJobOwner = ""; newJobCategory = ""
        newStepName = "Step 1"; newStepDatabase = ""; newStepCommand = ""
        addDailySchedule = false; scheduleName = "Daily"; scheduleEnabled = true; scheduleStartHHMMSS = "090000"; scheduleInterval = "1"
        wizardSteps = []; startStepId = nil; wizardSchedules = []; notifyOperatorName = ""; notifyLevel = .none
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
