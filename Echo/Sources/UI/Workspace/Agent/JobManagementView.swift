import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class JobManagementViewModel: ObservableObject {
    struct JobRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let category: String?; let owner: String?; let lastOutcome: String?; let nextRun: String? }
    struct StepRow: Identifiable, Hashable { let id: Int; let name: String; let subsystem: String; let database: String?; let command: String? }
    struct ScheduleRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let freqType: Int; let next: String? }
    struct PropertySheet: Equatable { var description: String?; var owner: String?; var category: String?; var enabled: Bool; var startStepId: Int? }
    struct HistoryRow: Identifiable, Hashable { let id: Int; let jobName: String; let stepId: Int; let status: Int; let message: String; let runDate: Int; let runTime: Int; let runDuration: Int }

    private let session: DatabaseSession
    private let connection: SavedConnection

    @Published private(set) var jobs: [JobRow] = []
    @Published var selectedJobID: String? { didSet { Task { await loadDetailsAndHistory() } } }
    @Published private(set) var properties: PropertySheet?
    @Published private(set) var steps: [StepRow] = []
    @Published private(set) var schedules: [ScheduleRow] = []
    @Published private(set) var history: [HistoryRow] = []
    @Published private(set) var isLoadingJobs = false
    @Published private(set) var isLoadingDetails = false
    @Published private(set) var errorMessage: String?

    init(session: DatabaseSession, connection: SavedConnection, initialSelectedJobID: String? = nil) {
        self.session = session
        self.connection = connection
        self.selectedJobID = initialSelectedJobID
    }

    func loadInitial() async {
        await loadJobs()
        await loadHistory(all: true)
    }

    func reloadJobs() async { await loadJobs() }

    private func loadJobs() async {
        isLoadingJobs = true
        defer { isLoadingJobs = false }
        do {
            let sql = """
            SELECT
                job_id = CONVERT(nvarchar(36), j.job_id),
                j.name,
                j.enabled,
                owner_name = SUSER_SNAME(j.owner_sid),
                category = c.name,
                last_outcome = CASE last.run_status
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Canceled'
                    WHEN 4 THEN 'In Progress'
                    ELSE NULL
                END,
                next_run = CASE WHEN nx.next_run_date IS NULL THEN NULL ELSE RIGHT('00000000' + CONVERT(varchar(8), nx.next_run_date), 8) + ' ' + RIGHT('000000' + CONVERT(varchar(6), nx.next_run_time), 6) END
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            OUTER APPLY (
                SELECT TOP (1) run_status
                FROM msdb.dbo.sysjobhistory AS h
                WHERE h.job_id = j.job_id AND h.step_id = 0
                ORDER BY h.instance_id DESC
            ) AS last
            OUTER APPLY (
                SELECT TOP (1) js.next_run_date, js.next_run_time
                FROM msdb.dbo.sysjobschedules AS js
                WHERE js.job_id = j.job_id
                ORDER BY js.next_run_date, js.next_run_time
            ) AS nx
            ORDER BY j.name;
            """
            let rs = try await session.simpleQuery(sql)
            let idx: (String) -> Int = { name in rs.columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0 }
            let items = rs.rows.compactMap { row -> JobRow? in
                guard let name = row[safe: idx("name")] else { return nil }
                let id = row[safe: idx("job_id")] ?? name
                let enabled = (row[safe: idx("enabled")] ?? "0") == "1"
                let owner = row[safe: idx("owner_name")]
                let category = row[safe: idx("category")]
                let outcome = row[safe: idx("last_outcome")]
                let nextRun = row[safe: idx("next_run")]
                return JobRow(id: id, name: name, enabled: enabled, category: category, owner: owner, lastOutcome: outcome, nextRun: nextRun)
            }
            self.jobs = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadDetailsAndHistory() async {
        await loadDetails()
        await loadHistory(all: selectedJobID == nil)
    }

    // MARK: - Actions (Jobs)

    func startSelectedJob() async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_start_job @job_id = N'\(jobID)';"
        _ = try? await session.simpleQuery(sql)
        await loadHistory(all: false)
    }

    func stopSelectedJob() async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_stop_job @job_id = N'\(jobID)';"
        _ = try? await session.simpleQuery(sql)
        await loadHistory(all: false)
    }

    func setSelectedJobEnabled(_ enabled: Bool) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_update_job @job_id = N'\(jobID)', @enabled = \(enabled ? 1 : 0);"
        _ = try? await session.simpleQuery(sql)
        await loadJobs()
    }

    // MARK: - Actions (Properties)

    func updateProperties(_ sheet: PropertySheet) async {
        guard let jobID = selectedJobID else { return }
        var parts: [String] = ["@job_id = N'\(jobID)'"]
        if let desc = sheet.description { parts.append("@description = N'\(escape(desc))'") }
        if let owner = sheet.owner { parts.append("@owner_login_name = N'\(escape(owner))'") }
        if let cat = sheet.category { parts.append("@category_name = N'\(escape(cat))'") }
        parts.append("@enabled = \(sheet.enabled ? 1 : 0)")
        if let start = sheet.startStepId, start > 0 { parts.append("@start_step_id = \(start)") }
        let sql = "EXEC msdb.dbo.sp_update_job \(parts.joined(separator: ", "));"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadJobs(); await loadDetails()
    }

    // MARK: - Actions (Steps)

    func addTSQLStep(name: String, database: String?, command: String) async {
        guard let jobID = selectedJobID else { return }
        var sql = "EXEC msdb.dbo.sp_add_jobstep @job_id = N'\(jobID)', @step_name = N'\(escape(name))', @subsystem = N'TSQL', @command = N'\(escape(command))'"
        if let db = database, !db.isEmpty { sql += ", @database_name = N'\(escape(db))'" }
        sql += ";"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    func updateTSQLStep(stepID: Int, name: String, database: String?, command: String) async {
        guard let jobID = selectedJobID else { return }
        var sql = "EXEC msdb.dbo.sp_update_jobstep @job_id = N'\(jobID)', @step_id = \(stepID), @step_name = N'\(escape(name))', @command = N'\(escape(command))'"
        if let db = database, !db.isEmpty { sql += ", @database_name = N'\(escape(db))'" }
        sql += ";"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    func deleteStep(stepID: Int) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_delete_jobstep @job_id = N'\(jobID)', @step_id = \(stepID);"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    // MARK: - Actions (Schedules)

    func addAndAttachSchedule(name: String, enabled: Bool, freqType: Int = 4, freqInterval: Int = 1) async {
        guard let jobID = selectedJobID else { return }
        // Create schedule
        let create = "EXEC msdb.dbo.sp_add_schedule @schedule_name = N'\(escape(name))', @enabled = \(enabled ? 1 : 0), @freq_type = \(freqType), @freq_interval = \(freqInterval);"
        do { _ = try await session.simpleQuery(create) } catch { errorMessage = error.localizedDescription; return }
        // Lookup schedule_id and attach
        let lookup = try? await session.simpleQuery("SELECT schedule_id FROM msdb.dbo.sysschedules WHERE name = N'\(escape(name))'")
        let scheduleID = lookup?.rows.first?[safe: lookup!.index(of: "schedule_id")] ?? ""
        guard !scheduleID.isEmpty else { return }
        let attach = "EXEC msdb.dbo.sp_attach_schedule @job_id = N'\(jobID)', @schedule_id = \(scheduleID);"
        _ = try? await session.simpleQuery(attach)
        await loadDetails()
    }

    func detachSchedule(scheduleID: String) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_detach_schedule @job_id = N'\(jobID)', @schedule_id = \(scheduleID);"
        _ = try? await session.simpleQuery(sql)
        await loadDetails()
    }

    // MARK: - Util
    private func escape(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }

    private func loadDetails() async {
        guard let jobID = selectedJobID, !jobID.isEmpty else {
            properties = nil; steps = []; schedules = []; return
        }
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let propSQL = """
            SELECT
                j.description,
                owner_name = SUSER_SNAME(j.owner_sid),
                category = c.name,
                j.enabled,
                j.start_step_id,
                j.name
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            WHERE j.job_id = CONVERT(uniqueidentifier, N'\(jobID)');
            """
            let rs = try await session.simpleQuery(propSQL)
            if let row = rs.rows.first {
                let desc = row[safe: rs.index(of: "description")]
                let owner = row[safe: rs.index(of: "owner_name")]
                let category = row[safe: rs.index(of: "category")]
                let enabled = (row[safe: rs.index(of: "enabled")] ?? "0") == "1"
                let start = Int(row[safe: rs.index(of: "start_step_id")] ?? "")
                self.properties = PropertySheet(description: desc, owner: owner, category: category, enabled: enabled, startStepId: start)
            } else {
                self.properties = nil
            }

            let stepsSQL = """
            SELECT s.step_id, s.step_name, s.subsystem, s.database_name, s.command
            FROM msdb.dbo.sysjobsteps AS s
            INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id = s.job_id
            WHERE j.job_id = CONVERT(uniqueidentifier, N'\(jobID)')
            ORDER BY s.step_id;
            """
            let srs = try await session.simpleQuery(stepsSQL)
            let sitems: [StepRow] = srs.rows.compactMap { row in
                let id = Int(row[safe: srs.index(of: "step_id")] ?? "") ?? 0
                let name = row[safe: srs.index(of: "step_name")] ?? ""
                let subsystem = row[safe: srs.index(of: "subsystem")] ?? ""
                let db = row[safe: srs.index(of: "database_name")]
                let cmd = row[safe: srs.index(of: "command")]
                return StepRow(id: id, name: name, subsystem: subsystem, database: db, command: cmd)
            }
            self.steps = sitems

            let schedSQL = """
            SELECT sc.schedule_id, sc.name, sc.enabled, sc.freq_type,
                   next_run = CASE WHEN js.next_run_date IS NULL THEN NULL ELSE RIGHT('00000000'+CONVERT(varchar(8), js.next_run_date), 8)+' '+RIGHT('000000'+CONVERT(varchar(6), js.next_run_time), 6) END
            FROM msdb.dbo.sysschedules AS sc
            INNER JOIN msdb.dbo.sysjobschedules AS js ON js.schedule_id = sc.schedule_id
            WHERE js.job_id = CONVERT(uniqueidentifier, N'\(jobID)')
            ORDER BY sc.name;
            """
            let q = try await session.simpleQuery(schedSQL)
            let sch: [ScheduleRow] = q.rows.compactMap { row in
                let id = row[safe: q.index(of: "schedule_id")] ?? UUID().uuidString
                let name = row[safe: q.index(of: "name")] ?? ""
                let enabled = (row[safe: q.index(of: "enabled")] ?? "0") == "1"
                let freq = Int(row[safe: q.index(of: "freq_type")] ?? "") ?? 0
                let next = row[safe: q.index(of: "next_run")]
                return ScheduleRow(id: id, name: name, enabled: enabled, freqType: freq, next: next)
            }
            self.schedules = sch
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadHistory(all: Bool) async {
        do {
            let filter = (!all && selectedJobID != nil) ? "WHERE h.job_id = CONVERT(uniqueidentifier, N'\(selectedJobID!)')" : ""
            let sql = """
            SELECT TOP (200)
                h.instance_id,
                j.name AS job_name,
                h.step_id,
                h.run_status,
                h.message,
                h.run_date,
                h.run_time,
                h.run_duration
            FROM msdb.dbo.sysjobhistory AS h
            INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
            \(filter)
            ORDER BY h.instance_id DESC;
            """
            let rs = try await session.simpleQuery(sql)
            let items: [HistoryRow] = rs.rows.compactMap { row in
                let id = Int(row[safe: rs.index(of: "instance_id")] ?? "") ?? 0
                let job = row[safe: rs.index(of: "job_name")] ?? ""
                let step = Int(row[safe: rs.index(of: "step_id")] ?? "") ?? 0
                let status = Int(row[safe: rs.index(of: "run_status")] ?? "") ?? 0
                let msg = row[safe: rs.index(of: "message")] ?? ""
                let rdate = Int(row[safe: rs.index(of: "run_date")] ?? "") ?? 0
                let rtime = Int(row[safe: rs.index(of: "run_time")] ?? "") ?? 0
                let dur = Int(row[safe: rs.index(of: "run_duration")] ?? "") ?? 0
                return HistoryRow(id: id, jobName: job, stepId: step, status: status, message: msg, runDate: rdate, runTime: rtime, runDuration: dur)
            }
            self.history = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

private extension QueryResultSet {
    func index(of name: String) -> Int { columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0 }
}

private extension Array where Element == String? {
    subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - View

struct JobManagementView: View {
    @ObservedObject var viewModel: JobManagementViewModel
    @State private var verticalRatio: CGFloat = 0.6
    @State private var horizontalRatio: CGFloat = 0.45
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selection: Set<String> = []
    // Properties editing
    @State private var editingProps: JobManagementViewModel.PropertySheet? = nil
    // Step editing
    @State private var newStepName: String = ""
    @State private var newStepDatabase: String = ""
    @State private var newStepCommand: String = ""
    @State private var selectedStepID: Int? = nil
    @State private var editStepName: String = ""
    @State private var editStepDatabase: String = ""
    @State private var editStepCommand: String = ""
    // Schedule editing
    @State private var newScheduleName: String = ""
    @State private var newScheduleEnabled: Bool = true
    @State private var newScheduleFreqType: Int = 4
    @State private var newScheduleFreqInterval: Int = 1

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    jobsTable
                        .frame(width: geo.size.width * horizontalRatio)
                    Divider()
                    jobDetails
                        .frame(width: geo.size.width * (1 - horizontalRatio))
                }
                .frame(height: totalHeight * verticalRatio)

                ResizeHandle(
                    ratio: verticalRatio,
                    minRatio: 0.3,
                    maxRatio: 0.85,
                    availableHeight: totalHeight,
                    onLiveUpdate: { proposed in verticalRatio = min(max(proposed, 0.3), 0.85) },
                    onCommit: { proposed in verticalRatio = min(max(proposed, 0.3), 0.85) }
                )

                historyTable
                    .frame(height: totalHeight * (1 - verticalRatio))
            }
        }
        .task { await viewModel.loadInitial() }
    }

    // MARK: - Subviews

    private var jobsTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jobs").font(.headline)
                Spacer()
                if viewModel.isLoadingJobs { ProgressView().controlSize(.small) }
                Button {
                    Task { await viewModel.reloadJobs() }
                } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Table(of: JobManagementViewModel.JobRow.self, selection: Binding(get: {
                if let id = viewModel.selectedJobID { return Set([id]) } else { return Set<String>() }
            }, set: { newSel in
                viewModel.selectedJobID = newSel.first
                selection = newSel
            })) {
                TableColumn("Enabled") { job in
                    Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                        .foregroundStyle(job.enabled ? .green : .secondary)
                }.width(28)
                TableColumn("Name", value: \.name)
                TableColumn("Owner") { job in Text(job.owner ?? "—").foregroundStyle(job.owner == nil ? .secondary : .primary) }
                TableColumn("Category") { job in Text(job.category ?? "—").foregroundStyle(job.category == nil ? .secondary : .primary) }
                TableColumn("Last Outcome") { job in Text(job.lastOutcome ?? "—").foregroundStyle(job.lastOutcome == nil ? .secondary : .primary) }
                TableColumn("Next Run") { job in Text(job.nextRun ?? "—").foregroundStyle(job.nextRun == nil ? .secondary : .primary) }
            } rows: {
                ForEach(viewModel.jobs) { job in TableRow(job) }
            }
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first {
                    Button("Start Job") { Task { viewModel.selectedJobID = id; await viewModel.startSelectedJob() } }
                    Button("Stop Job") { Task { viewModel.selectedJobID = id; await viewModel.stopSelectedJob() } }
                    Divider()
                    Button("Enable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(true) } }
                    Button("Disable") { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(false) } }
                }
            }
        }
    }

    private var jobDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline).padding(.horizontal, 12).padding(.top, 6)
            if let props = viewModel.properties {
                let boundProps = Binding<JobManagementViewModel.PropertySheet>(
                    get: { editingProps ?? props },
                    set: { editingProps = $0 }
                )
                TabView {
                    // Properties tab (editable)
                    Form {
                        Toggle("Enabled", isOn: Binding(get: { boundProps.wrappedValue.enabled }, set: { boundProps.wrappedValue.enabled = $0 }))
                        TextField("Owner", text: Binding(get: { boundProps.wrappedValue.owner ?? "" }, set: { boundProps.wrappedValue.owner = $0 }))
                        TextField("Category", text: Binding(get: { boundProps.wrappedValue.category ?? "" }, set: { boundProps.wrappedValue.category = $0 }))
                        TextField("Description", text: Binding(get: { boundProps.wrappedValue.description ?? "" }, set: { boundProps.wrappedValue.description = $0 }))
                        if let start = boundProps.wrappedValue.startStepId { Stepper("Start Step: \(start)", value: Binding(get: { start }, set: { boundProps.wrappedValue.startStepId = $0 })) }
                        HStack {
                            Button("Save") { Task { await viewModel.updateProperties(boundProps.wrappedValue); editingProps = nil } }
                            Button("Revert") { editingProps = nil }
                            Spacer()
                            Button("Start Job") { Task { await viewModel.startSelectedJob() } }
                            Button("Stop Job") { Task { await viewModel.stopSelectedJob() } }
                        }
                    }
                    .padding(.horizontal, 12)
                    .tabItem { Text("Properties") }

                    // Steps tab (add/edit/delete)
                    VStack(alignment: .leading) {
                        Table(of: JobManagementViewModel.StepRow.self, selection: Binding(get: {
                            if let id = selectedStepID { return Set([id]) } else { return Set<Int>() }
                        }, set: { sel in selectedStepID = sel.first })) {
                            TableColumn("ID") { s in Text("\(s.id)") }.width(32)
                            TableColumn("Name", value: \.name)
                            TableColumn("Subsystem", value: \.subsystem)
                            TableColumn("Database") { s in Text(s.database ?? "—").foregroundStyle(.secondary) }
                        } rows: {
                            ForEach(viewModel.steps) { s in TableRow(s) }
                        }
                        .frame(maxHeight: 200)

                        Divider().padding(.vertical, 4)

                        Text("Add Step").font(.subheadline)
                        HStack { TextField("Name", text: $newStepName); TextField("Database (optional)", text: $newStepDatabase) }
                        TextField("Command", text: $newStepCommand, axis: .vertical)
                        HStack { Button("Add") { Task { await viewModel.addTSQLStep(name: newStepName, database: newStepDatabase.isEmpty ? nil : newStepDatabase, command: newStepCommand); newStepName = ""; newStepDatabase = ""; newStepCommand = "" } }; Spacer() }

                        if let sid = selectedStepID, let step = viewModel.steps.first(where: { $0.id == sid }) {
                            Divider().padding(.vertical, 4)
                            Text("Edit Step #\(sid)").font(.subheadline)
                            HStack { TextField("Name", text: Binding(get: { editStepName.isEmpty ? step.name : editStepName }, set: { editStepName = $0 })); TextField("Database (optional)", text: Binding(get: { editStepDatabase.isEmpty ? (step.database ?? "") : editStepDatabase }, set: { editStepDatabase = $0 })) }
                            TextField("Command", text: Binding(get: { editStepCommand.isEmpty ? (step.command ?? "") : editStepCommand }, set: { editStepCommand = $0 }), axis: .vertical)
                            HStack {
                                Button("Update") { Task { await viewModel.updateTSQLStep(stepID: sid, name: editStepName.isEmpty ? step.name : editStepName, database: (editStepDatabase.isEmpty ? step.database : editStepDatabase), command: editStepCommand.isEmpty ? (step.command ?? "") : editStepCommand); editStepName = ""; editStepDatabase = ""; editStepCommand = "" } }
                                Button("Delete", role: .destructive) { Task { await viewModel.deleteStep(stepID: sid); selectedStepID = nil; editStepName = ""; editStepDatabase = ""; editStepCommand = "" } }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .tabItem { Text("Steps") }

                    // Schedules tab (attach/detach)
                    VStack(alignment: .leading) {
                        Table(of: JobManagementViewModel.ScheduleRow.self) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Enabled") { sch in Image(systemName: sch.enabled ? "checkmark.circle" : "xmark.circle").foregroundStyle(sch.enabled ? .green : .secondary) }.width(28)
                            TableColumn("Frequency") { sch in Text("\(sch.freqType)") }
                            TableColumn("Next Run") { sch in Text(sch.next ?? "—").foregroundStyle(.secondary) }
                        } rows: {
                            ForEach(viewModel.schedules) { sch in TableRow(sch).contextMenu { Button("Detach") { Task { await viewModel.detachSchedule(scheduleID: sch.id) } } } }
                        }
                        .frame(maxHeight: 220)

                        Divider().padding(.vertical, 4)
                        Text("Add Schedule").font(.subheadline)
                        HStack { TextField("Name", text: $newScheduleName); Toggle("Enabled", isOn: $newScheduleEnabled) }
                        HStack { TextField("Freq Type (4=Daily)", value: $newScheduleFreqType, formatter: NumberFormatter()); TextField("Freq Interval", value: $newScheduleFreqInterval, formatter: NumberFormatter()) }
                        Button("Create & Attach") { Task { await viewModel.addAndAttachSchedule(name: newScheduleName, enabled: newScheduleEnabled, freqType: newScheduleFreqType, freqInterval: newScheduleFreqInterval); newScheduleName = ""; newScheduleEnabled = true } }
                    }
                    .padding(.horizontal, 12)
                    .tabItem { Text("Schedules") }

                    // Notifications (placeholder)
                    VStack(alignment: .leading) {
                        Text("Job-level notifications are displayed in Properties.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .tabItem { Text("Notifications") }
                }
                .tabViewStyle(.automatic)
            } else {
                Text("Select a job to view details.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            Spacer()
        }
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Table(of: JobManagementViewModel.HistoryRow.self) {
                TableColumn("Job") { h in Text(h.jobName) }
                TableColumn("Step") { h in Text("\(h.stepId)") }.width(44)
                TableColumn("Status") { h in Text(jobStatusLabel(h.status)).foregroundStyle(colorForStatus(h.status)) }
                TableColumn("Run Date") { h in Text(formatAgentDate(h.runDate, h.runTime)) }
                TableColumn("Duration") { h in Text(formatDuration(h.runDuration)) }
                TableColumn("Message") { h in Text(h.message).lineLimit(1).truncationMode(.tail) }
            } rows: {
                ForEach(viewModel.history) { h in TableRow(h) }
            }
        }
    }
}

// MARK: - Utilities

private func formatAgentDate(_ dateInt: Int, _ timeInt: Int) -> String {
    guard dateInt > 0 else { return "—" }
    let yyyy = dateInt / 10000
    let mm = (dateInt / 100) % 100
    let dd = dateInt % 100
    let hh = timeInt / 10000
    let mi = (timeInt / 100) % 100
    let ss = timeInt % 100
    let comps = DateComponents(year: yyyy, month: mm, day: dd, hour: hh, minute: mi, second: ss)
    if let date = Calendar(identifier: .gregorian).date(from: comps) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
    return "—"
}

private func jobStatusLabel(_ status: Int) -> String {
    switch status { case 0: return "Failed"; case 1: return "Succeeded"; case 2: return "Retry"; case 3: return "Canceled"; case 4: return "In Progress"; default: return "?" }
}

private func colorForStatus(_ status: Int) -> Color {
    switch status { case 1: return .green; case 0: return .red; case 4: return .yellow; default: return .secondary }
}

private func formatDuration(_ runDuration: Int) -> String {
    let hours = runDuration / 10000
    let minutes = (runDuration / 100) % 100
    let seconds = runDuration % 100
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
