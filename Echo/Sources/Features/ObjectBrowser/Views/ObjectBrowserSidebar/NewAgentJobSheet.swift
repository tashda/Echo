import SwiftUI
import SQLServerKit

struct NewAgentJobSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onComplete: () -> Void

    @State private var jobName = ""
    @State private var jobDescription = ""
    @State private var jobEnabled = true
    @State private var jobOwner = ""
    @State private var jobCategory = ""
    @State private var startAfterCreate = false

    // Steps
    @State private var steps: [StepEntry] = []
    @State private var startStepId: Int = 1

    // Schedules
    @State private var schedules: [ScheduleEntry] = []

    // Notifications
    @State private var notifyOperator = ""
    @State private var notifyLevel: NotifyLevelChoice = .none

    @State private var errorMessage: String?
    @State private var isCreating = false

    @State private var selectedTab = 0

    private var isFormValid: Bool {
        !jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "info.circle") }
                    .tag(0)
                stepsTab
                    .tabItem { Label("Steps", systemImage: "list.number") }
                    .tag(1)
                schedulesTab
                    .tabItem { Label("Schedules", systemImage: "calendar") }
                    .tag(2)
                notificationsTab
                    .tabItem { Label("Notifications", systemImage: "bell") }
                    .tag(3)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 540, minHeight: 440)
        .onAppear { loadCurrentLogin() }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .keyboardShortcut(.cancelAction)

            Button("Create Job") {
                Task { await createJob() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md2)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("New Agent Job") {
                TextField("Name", text: $jobName)
                TextField("Description", text: $jobDescription, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Enabled", isOn: $jobEnabled)
                Toggle("Start after creation", isOn: $startAfterCreate)
            }
            Section("Ownership") {
                TextField("Owner", text: $jobOwner, prompt: Text("Current login"))
                TextField("Category", text: $jobCategory, prompt: Text("None"))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Steps Tab

    private var stepsTab: some View {
        Form {
            if steps.isEmpty {
                Section {
                    Text("No steps added yet. Add a step to define what this job does.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                Section("Step \(index + 1)") {
                    TextField("Name", text: $steps[index].name)
                    Picker("Type", selection: $steps[index].subsystem) {
                        Text("T-SQL").tag(SubsystemChoice.tsql)
                        Text("CmdExec").tag(SubsystemChoice.cmdExec)
                        Text("PowerShell").tag(SubsystemChoice.powershell)
                    }
                    if steps[index].subsystem == .tsql {
                        TextField("Database", text: $steps[index].database)
                    }
                    TextField("Command", text: $steps[index].command, axis: .vertical)
                        .lineLimit(2...6)
                        .font(TypographyTokens.monospaced)

                    Button("Remove Step", role: .destructive) {
                        steps.remove(at: index)
                    }
                    .controlSize(.small)
                }
            }

            Section {
                HStack {
                    Button {
                        steps.append(StepEntry(name: "Step \(steps.count + 1)"))
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }

                    Spacer()

                    if steps.count > 1 {
                        Picker("Start step", selection: $startStepId) {
                            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                Text("\(index + 1). \(step.name)").tag(index + 1)
                            }
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Schedules Tab

    private var schedulesTab: some View {
        Form {
            if schedules.isEmpty {
                Section {
                    Text("No schedules added yet. Add a schedule to run this job automatically.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            ForEach(Array(schedules.enumerated()), id: \.element.id) { index, _ in
                Section(schedules[index].name.isEmpty ? "Schedule \(index + 1)" : schedules[index].name) {
                    TextField("Name", text: $schedules[index].name)
                    Toggle("Enabled", isOn: $schedules[index].enabled)
                    Picker("Frequency", selection: $schedules[index].mode) {
                        ForEach(ScheduleModeChoice.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    scheduleFrequencyOptions(index: index)

                    scheduleSummary(for: schedules[index])

                    Button("Remove Schedule", role: .destructive) {
                        schedules.remove(at: index)
                    }
                    .controlSize(.small)
                }
            }

            Section {
                Button {
                    schedules.append(ScheduleEntry())
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func scheduleFrequencyOptions(index: Int) -> some View {
        switch schedules[index].mode {
        case .daily:
            Stepper("Every \(schedules[index].intervalDays) day(s)", value: $schedules[index].intervalDays, in: 1...365)
        case .weekly:
            Stepper("Every \(schedules[index].intervalWeeks) week(s)", value: $schedules[index].intervalWeeks, in: 1...52)
            weekdayToggles(index: index)
        case .monthly:
            Stepper("Every \(schedules[index].intervalMonths) month(s)", value: $schedules[index].intervalMonths, in: 1...12)
            Stepper("On day \(schedules[index].monthDay) of the month", value: $schedules[index].monthDay, in: 1...31)
        case .once:
            DatePicker("Run on", selection: $schedules[index].oneTimeDate, displayedComponents: .date)
        }

        // Time picker
        HStack {
            Text("At")
            Picker("Hour", selection: $schedules[index].startHour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d", h)).tag(h) }
            }
            .frame(width: 70)
            .labelsHidden()
            Text(":")
            Picker("Minute", selection: $schedules[index].startMinute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 70)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func weekdayToggles(index: Int) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(Weekday.allCases) { day in
                Toggle(day.shortName, isOn: Binding(
                    get: { schedules[index].weekdays.contains(day) },
                    set: { on in
                        if on { schedules[index].weekdays.insert(day) }
                        else { schedules[index].weekdays.remove(day) }
                    }
                ))
                .toggleStyle(.button)
                .controlSize(.small)
            }
        }
    }

    private func scheduleSummary(for entry: ScheduleEntry) -> some View {
        let timeStr = String(format: "%02d:%02d", entry.startHour, entry.startMinute)
        let summary: String
        switch entry.mode {
        case .daily:
            summary = entry.intervalDays == 1
                ? "Runs every day at \(timeStr)"
                : "Runs every \(entry.intervalDays) days at \(timeStr)"
        case .weekly:
            let dayNames = Weekday.allCases.filter { entry.weekdays.contains($0) }.map(\.shortName).joined(separator: ", ")
            let days = dayNames.isEmpty ? "no days selected" : dayNames
            summary = entry.intervalWeeks == 1
                ? "Runs every week on \(days) at \(timeStr)"
                : "Runs every \(entry.intervalWeeks) weeks on \(days) at \(timeStr)"
        case .monthly:
            summary = entry.intervalMonths == 1
                ? "Runs on the \(ordinal(entry.monthDay)) of every month at \(timeStr)"
                : "Runs on the \(ordinal(entry.monthDay)) every \(entry.intervalMonths) months at \(timeStr)"
        case .once:
            let dateStr = entry.oneTimeDate.formatted(date: .abbreviated, time: .omitted)
            summary = "Runs once on \(dateStr) at \(timeStr)"
        }

        return Text(summary)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10, tens = n % 100
        if tens >= 11 && tens <= 13 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        Form {
            Section("Email Notification") {
                TextField("Operator name", text: $notifyOperator)
                Picker("Notify level", selection: $notifyLevel) {
                    ForEach(NotifyLevelChoice.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func loadCurrentLogin() {
        guard jobOwner.isEmpty else { return }
        Task {
            do {
                let rs = try await session.session.simpleQuery("SELECT SUSER_SNAME() AS name;")
                let val = rs.rows.first?[0] ?? ""
                await MainActor.run { jobOwner = val }
            } catch { }
        }
    }

    private func createJob() async {
        let name = jobName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Job name is required"
            return
        }
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let agent = mssql.agent
            let builder = SQLServerAgentJobBuilder(
                agent: agent,
                jobName: name,
                description: jobDescription.isEmpty ? nil : jobDescription,
                enabled: jobEnabled,
                ownerLoginName: jobOwner.isEmpty ? nil : jobOwner,
                categoryName: jobCategory.isEmpty ? nil : jobCategory,
                autoAttachServer: true
            )

            // Add steps
            for step in steps {
                let s = SQLServerAgentJobStep(
                    name: step.name,
                    subsystem: step.subsystem.builderSubsystem,
                    command: step.command,
                    database: step.database.isEmpty ? nil : step.database
                )
                _ = builder.addStep(s)
            }

            if steps.count > 1 {
                _ = builder.setStartStepId(startStepId)
            }

            // Add schedules
            for schedule in schedules {
                let startTimeInt = schedule.startTimeInt
                let kind: SQLServerAgentJobSchedule.Kind
                switch schedule.mode {
                case .daily:
                    kind = .daily(everyDays: max(1, schedule.intervalDays), startTime: startTimeInt)
                case .weekly:
                    let days: [SQLServerAgentJobSchedule.WeeklyDay] = Weekday.allCases
                        .filter { schedule.weekdays.contains($0) }
                        .compactMap { day -> SQLServerAgentJobSchedule.WeeklyDay? in
                            switch day {
                            case .sunday: return .sunday
                            case .monday: return .monday
                            case .tuesday: return .tuesday
                            case .wednesday: return .wednesday
                            case .thursday: return .thursday
                            case .friday: return .friday
                            case .saturday: return .saturday
                            }
                        }
                    kind = .weekly(days: days.isEmpty ? [.monday] : days, everyWeeks: schedule.intervalWeeks, startTime: startTimeInt)
                case .monthly:
                    kind = .monthly(day: schedule.monthDay, everyMonths: schedule.intervalMonths, startTime: startTimeInt)
                case .once:
                    let comps = Calendar.current.dateComponents([.year, .month, .day], from: schedule.oneTimeDate)
                    let dateInt = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
                    kind = .oneTime(startDate: dateInt, startTime: startTimeInt)
                }

                let scheduleName = schedule.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let sch = SQLServerAgentJobSchedule(
                    name: scheduleName.isEmpty ? "Schedule_\(name)" : scheduleName,
                    enabled: schedule.enabled,
                    kind: kind
                )
                _ = builder.addSchedule(sch)
            }

            // Notification
            if !notifyOperator.isEmpty && notifyLevel != .none {
                let level: SQLServerAgentJobNotification.Level
                switch notifyLevel {
                case .none: level = .none
                case .success: level = .onSuccess
                case .failure: level = .onFailure
                case .completion: level = .onCompletion
                }
                _ = builder.setNotification(SQLServerAgentJobNotification(
                    operatorName: notifyOperator,
                    level: level
                ))
            }

            let (_, jobId) = try await builder.commit()

            if startAfterCreate {
                _ = try? await agent.startJob(named: name)
            }

            await MainActor.run {
                isCreating = false
                environmentState.openJobQueueTab(for: session, selectJobID: jobId)
                onComplete()
            }
        } catch {
            await MainActor.run {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Supporting Types

private enum SubsystemChoice: String, CaseIterable {
    case tsql, cmdExec, powershell

    var builderSubsystem: SQLServerAgentJobStep.Subsystem {
        switch self {
        case .tsql: return .tsql
        case .cmdExec: return .cmdExec
        case .powershell: return .powershell
        }
    }
}

private struct StepEntry: Identifiable {
    let id = UUID()
    var name: String
    var subsystem: SubsystemChoice = .tsql
    var database: String = ""
    var command: String = ""
}

private enum ScheduleModeChoice: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case once = "One Time"
    var id: String { rawValue }
}

private enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case sunday = 1, monday = 2, tuesday = 4, wednesday = 8, thursday = 16, friday = 32, saturday = 64

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    /// Bitmask value for SQL Server's freq_interval
    var bitmask: Int { rawValue }
}

private struct ScheduleEntry: Identifiable {
    let id = UUID()
    var name: String = ""
    var enabled: Bool = true
    var mode: ScheduleModeChoice = .daily
    var startHour: Int = 9
    var startMinute: Int = 0
    var intervalDays: Int = 1
    var intervalWeeks: Int = 1
    var intervalMonths: Int = 1
    var monthDay: Int = 1
    var weekdays: Set<Weekday> = [.monday]
    var oneTimeDate: Date = Date()

    var startTimeInt: Int { startHour * 10000 + startMinute * 100 }

    var weekdayBitmask: Int {
        weekdays.reduce(0) { $0 | $1.bitmask }
    }
}

private enum NotifyLevelChoice: String, CaseIterable, Identifiable {
    case none = "None"
    case success = "On success"
    case failure = "On failure"
    case completion = "On completion"
    var id: String { rawValue }
}
