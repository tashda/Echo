import SwiftUI

struct JobDetailsView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    let toastCoordinator: StatusToastCoordinator

    // Properties editing
    @State private var editingProps: JobQueueViewModel.PropertySheet?

    // Step editing
    @State private var newStepName = ""
    @State private var newStepSubsystem = "TSQL"
    @State private var newStepDatabase = ""
    @State private var newStepCommand = ""
    @State private var selectedStepID: Int?

    // Command editor sheet (item-based for reliable data passing)
    @State private var commandEditorContext: CommandEditorContext?

    // Schedule editing
    @State private var newScheduleName = ""
    @State private var newScheduleEnabled = true
    @State private var newScheduleFrequency: ScheduleFrequency = .daily
    @State private var newScheduleInterval = 1
    @State private var newScheduleStartHour = 9
    @State private var newScheduleStartMinute = 0
    @State private var newScheduleWeekdays: Set<Int> = [2] // Monday
    @State private var newScheduleMonthDay = 1
    @State private var newScheduleStartDate = Date()
    @State private var newScheduleOneTimeDate = Date()

    // Notification editing
    @State private var notifyOperator = ""
    @State private var notifyLevel = 0 // 0=Never, 1=Success, 2=Failure, 3=Completion
    @State private var notifyEventLogLevel = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Details")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                if viewModel.isLoadingDetails {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)

            if viewModel.properties != nil {
                TabView {
                    propertiesTab
                        .tabItem { Label("Properties", systemImage: "info.circle") }
                    stepsTab
                        .tabItem { Label("Steps", systemImage: "list.number") }
                    schedulesTab
                        .tabItem { Label("Schedules", systemImage: "calendar") }
                    notificationsTab
                        .tabItem { Label("Notifications", systemImage: "bell") }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedJobID != nil {
                VStack {
                    ProgressView()
                    Text("Loading details...")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a job to view details.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $commandEditorContext) { context in
            commandEditorSheet(context: context)
        }
        .onChange(of: viewModel.properties) { _, _ in
            // Clear local editing state when server data refreshes
            editingProps = nil
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if let error {
                toastCoordinator.show(
                    icon: "exclamationmark.triangle.fill",
                    message: error,
                    style: .error,
                    duration: 5.0
                )
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Properties Tab

    private var propertiesTab: some View {
        let props = editingProps ?? viewModel.properties ?? JobQueueViewModel.PropertySheet(
            name: "", description: nil, owner: nil, category: nil, enabled: false, startStepId: nil
        )
        let boundProps = Binding<JobQueueViewModel.PropertySheet>(
            get: { editingProps ?? viewModel.properties ?? props },
            set: { editingProps = $0 }
        )

        return Form {
            Section("General") {
                TextField("Name", text: boundProps.name)

                Toggle("Enabled", isOn: boundProps.enabled)

                LabeledContent("Description") {
                    TextField("", text: Binding(
                        get: { boundProps.wrappedValue.description ?? "" },
                        set: { boundProps.wrappedValue.description = $0 }
                    ), axis: .vertical)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
                }
            }

            Section("Ownership") {
                LabeledContent("Owner") {
                    TextField("", text: Binding(
                        get: { boundProps.wrappedValue.owner ?? "" },
                        set: { boundProps.wrappedValue.owner = $0 }
                    ))
                    .multilineTextAlignment(.trailing)
                }

                if viewModel.categories.isEmpty {
                    LabeledContent("Category") {
                        TextField("", text: Binding(
                            get: { boundProps.wrappedValue.category ?? "" },
                            set: { boundProps.wrappedValue.category = $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                } else {
                    Picker("Category", selection: Binding(
                        get: { boundProps.wrappedValue.category ?? "[Uncategorized (Local)]" },
                        set: { boundProps.wrappedValue.category = $0 }
                    )) {
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
            }

            Section("Execution") {
                if viewModel.steps.isEmpty {
                    LabeledContent("Start Step") {
                        Text("No steps defined")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Start Step", selection: Binding(
                        get: { boundProps.wrappedValue.startStepId ?? 1 },
                        set: { boundProps.wrappedValue.startStepId = $0 }
                    )) {
                        ForEach(viewModel.steps) { step in
                            Text("\(step.id). \(step.name)")
                                .tag(step.id)
                        }
                    }
                }

                LabeledContent("Actions") {
                    HStack(spacing: SpacingTokens.sm) {
                        Button("Start Job") {
                            Task {
                                await viewModel.startSelectedJob()
                                if viewModel.errorMessage == nil {
                                    toastCoordinator.show(
                                        icon: "play.fill",
                                        message: "Job started",
                                        style: .success
                                    )
                                }
                            }
                        }
                        .disabled(viewModel.isJobRunning)

                        if viewModel.isJobRunning {
                            Button("Stop Job") {
                                Task {
                                    await viewModel.stopSelectedJob()
                                    if viewModel.errorMessage == nil {
                                        toastCoordinator.show(icon: "stop.fill", message: "Job stopped", style: .success)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let editing = editingProps, editing != viewModel.properties {
                Section {
                    HStack {
                        Spacer()
                        Button("Revert") {
                            editingProps = nil
                        }
                        Button("Save Changes") {
                            Task {
                                await viewModel.updateProperties(boundProps.wrappedValue)
                                if viewModel.errorMessage == nil {
                                    editingProps = nil
                                    toastCoordinator.show(icon: "checkmark.circle.fill", message: "Properties saved", style: .success)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Steps Tab

    private var isAddStepDisabled: Bool {
        newStepName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || newStepCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var stepsTab: some View {
        VSplitView {
            List {
                ForEach(viewModel.steps) { step in
                    stepListRow(step)
                        .contextMenu {
                            Button("Open Command in Editor") {
                                openCommandEditor(text: step.command ?? "", stepName: step.name)
                            }
                            Divider()
                            Button("Delete Step", role: .destructive) {
                                Task { await viewModel.deleteStep(stepName: step.name) }
                            }
                        }
                }
                .onMove(perform: moveSteps)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, minHeight: 40)

            ScrollView {
                addStepForm
            }
            .frame(minHeight: 40)
        }
    }

    private func stepListRow(_ step: JobQueueViewModel.StepRow) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("\(step.id)")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(step.name)
                        .font(TypographyTokens.standard)

                    Text(step.subsystem)
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06), in: Capsule())

                    if let db = step.database, !db.isEmpty {
                        Text(db)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let cmd = step.command, !cmd.isEmpty {
                    Text(cmd.prefix(80).description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if step.command != nil {
                Button {
                    openCommandEditor(text: step.command ?? "", stepName: step.name)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open in editor")
            }
        }
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        Task {
            await viewModel.reorderSteps(from: source, to: destination)
        }
    }

    private func openCommandEditor(text: String, stepName: String? = nil) {
        commandEditorContext = CommandEditorContext(stepName: stepName, initialText: text)
    }

    private var addStepForm: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Add Step")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)

            HStack(spacing: SpacingTokens.sm) {
                TextField("Step Name", text: $newStepName)
                Picker("Type", selection: $newStepSubsystem) {
                    Text("T-SQL").tag("TSQL")
                    Text("CmdExec").tag("CmdExec")
                    Text("PowerShell").tag("PowerShell")
                }
                .fixedSize()
                if newStepSubsystem == "TSQL" {
                    Picker("Database", selection: $newStepDatabase) {
                        Text("Default").tag("")
                        ForEach(viewModel.databaseNames, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                    .frame(maxWidth: 160)
                }
            }
            .padding(.horizontal, SpacingTokens.md)

            HStack(spacing: SpacingTokens.xs) {
                TextField("Command", text: $newStepCommand, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .monospaced))
                Button {
                    openCommandEditor(text: newStepCommand, stepName: nil)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Open in full editor")
            }
            .padding(.horizontal, SpacingTokens.md)

            HStack {
                Spacer()
                Button("Add Step") {
                    let name = newStepName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let command = newStepCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !command.isEmpty else { return }
                    Task {
                        await viewModel.addStep(
                            name: name,
                            subsystem: newStepSubsystem,
                            database: newStepDatabase.isEmpty ? nil : newStepDatabase,
                            command: command
                        )
                        newStepName = ""
                        newStepDatabase = ""
                        newStepCommand = ""
                    }
                }
                .disabled(isAddStepDisabled)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.sm)
        }
    }

    // MARK: - Schedules Tab

    @State private var selectedScheduleID: Set<String> = []

    private var schedulesTab: some View {
        VSplitView {
            Table(of: JobQueueViewModel.ScheduleRow.self, selection: $selectedScheduleID) {
                TableColumn("") { sch in
                    Image(systemName: sch.enabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(sch.enabled ? .green : .secondary)
                }
                .width(24)

                TableColumn("Name", value: \.name)

                TableColumn("Frequency") { sch in
                    Text(frequencyDisplayName(sch.freqType))
                }

                TableColumn("Next Run") { sch in
                    if let next = sch.next {
                        Text(next)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
            } rows: {
                ForEach(viewModel.schedules) { sch in
                    TableRow(sch)
                }
            }
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first, let sch = viewModel.schedules.first(where: { $0.id == id }) {
                    Button("Detach Schedule", role: .destructive) {
                        Task { await viewModel.detachSchedule(scheduleName: sch.name) }
                    }
                }
            }
            .frame(minHeight: 40)

            newScheduleForm
                .frame(minHeight: 40)
        }
    }

    private var newScheduleForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("New Schedule")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Schedule Name", text: $newScheduleName)
                    .textFieldStyle(.roundedBorder)

                Picker("Frequency", selection: $newScheduleFrequency) {
                    ForEach(ScheduleFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }

                Divider()

                Text(scheduleRecurrenceHeader)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.secondary)

                scheduleRecurrenceContent

                Divider()

                Text("Start Time")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Time")
                    Spacer()
                    Picker("Hour", selection: $newScheduleStartHour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Text(":")
                        .font(TypographyTokens.standard.weight(.medium))

                    Picker("Minute", selection: $newScheduleStartMinute) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if newScheduleFrequency != .once {
                    DatePicker("Starting from", selection: $newScheduleStartDate, displayedComponents: .date)
                }

                Divider()

                scheduleNaturalLanguageSummary

                HStack {
                    Toggle("Enabled", isOn: $newScheduleEnabled)
                        .toggleStyle(.switch)
                        .fixedSize()

                    Spacer()

                    Button("Create") {
                        createSchedule()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newScheduleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    private var scheduleRecurrenceHeader: String {
        switch newScheduleFrequency {
        case .daily: return "Recurrence"
        case .weekly: return "Repeat On"
        case .monthly: return "Day of Month"
        case .once: return "Date"
        }
    }

    @ViewBuilder
    private var scheduleRecurrenceContent: some View {
        switch newScheduleFrequency {
        case .daily:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every day").tag(1)
                Text("Every 2 days").tag(2)
                Text("Every 3 days").tag(3)
                Text("Every 5 days").tag(5)
                Text("Every 7 days").tag(7)
                Text("Every 14 days").tag(14)
                Text("Every 30 days").tag(30)
            }

        case .weekly:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every week").tag(1)
                Text("Every 2 weeks").tag(2)
                Text("Every 3 weeks").tag(3)
                Text("Every 4 weeks").tag(4)
            }

            scheduleWeekdayPicker

        case .monthly:
            Picker("Repeat every", selection: $newScheduleInterval) {
                Text("Every month").tag(1)
                Text("Every 2 months").tag(2)
                Text("Every 3 months").tag(3)
                Text("Every 4 months").tag(4)
                Text("Every 6 months").tag(6)
                Text("Every 12 months").tag(12)
            }

            Picker("On day", selection: $newScheduleMonthDay) {
                ForEach(1...31, id: \.self) { d in
                    Text(ordinalDay(d)).tag(d)
                }
            }

        case .once:
            DatePicker("Run on", selection: $newScheduleOneTimeDate, displayedComponents: .date)
        }
    }

    private var scheduleWeekdayPicker: some View {
        HStack(spacing: 2) {
            ForEach([(1, "S"), (2, "M"), (4, "T"), (8, "W"), (16, "T"), (32, "F"), (64, "S")], id: \.0) { value, label in
                Toggle(isOn: Binding(
                    get: { newScheduleWeekdays.contains(value) },
                    set: { on in
                        if on { newScheduleWeekdays.insert(value) }
                        else if newScheduleWeekdays.count > 1 { newScheduleWeekdays.remove(value) }
                    }
                )) {
                    Text(label)
                        .font(TypographyTokens.detail.weight(.medium))
                        .frame(width: 22, height: 22)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }
        }
    }

    private var scheduleNaturalLanguageSummary: some View {
        let timeStr = String(format: "%02d:%02d", newScheduleStartHour, newScheduleStartMinute)
        let summary: String
        switch newScheduleFrequency {
        case .daily:
            summary = newScheduleInterval == 1
                ? "Runs every day at \(timeStr)"
                : "Runs every \(newScheduleInterval) days at \(timeStr)"
        case .weekly:
            let dayMap: [(Int, String)] = [(1, "Sunday"), (2, "Monday"), (4, "Tuesday"), (8, "Wednesday"), (16, "Thursday"), (32, "Friday"), (64, "Saturday")]
            let names = dayMap.filter { newScheduleWeekdays.contains($0.0) }.map(\.1).joined(separator: ", ")
            summary = newScheduleInterval == 1
                ? "Runs weekly on \(names.isEmpty ? "no days" : names) at \(timeStr)"
                : "Runs every \(newScheduleInterval) weeks on \(names.isEmpty ? "no days" : names) at \(timeStr)"
        case .monthly:
            let dayStr = ordinalDay(newScheduleMonthDay)
            summary = newScheduleInterval == 1
                ? "Runs on the \(dayStr) of every month at \(timeStr)"
                : "Runs on the \(dayStr) every \(newScheduleInterval) months at \(timeStr)"
        case .once:
            let dateStr = newScheduleOneTimeDate.formatted(date: .abbreviated, time: .omitted)
            summary = "Runs once on \(dateStr) at \(timeStr)"
        }

        return HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.secondary)
            Text(summary)
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
        }
    }

    private func ordinalDay(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10, tens = n % 100
        if tens >= 11 && tens <= 13 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }

    private func createSchedule() {
        let name = newScheduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let startTime = newScheduleStartHour * 10000 + newScheduleStartMinute * 100
        let freqInterval: Int
        switch newScheduleFrequency {
        case .daily: freqInterval = newScheduleInterval
        case .weekly: freqInterval = newScheduleWeekdays.reduce(0, |)
        case .monthly: freqInterval = newScheduleMonthDay
        case .once: freqInterval = 1
        }

        let activeStartDate: Int?
        if newScheduleFrequency == .once {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: newScheduleOneTimeDate)
            activeStartDate = (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        } else {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: newScheduleStartDate)
            activeStartDate = (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        }

        Task {
            await viewModel.addAndAttachSchedule(
                name: name,
                enabled: newScheduleEnabled,
                freqType: newScheduleFrequency.freqType,
                freqInterval: freqInterval,
                activeStartTime: startTime,
                freqRecurrenceFactor: newScheduleFrequency == .weekly ? newScheduleInterval :
                    newScheduleFrequency == .monthly ? newScheduleInterval : nil,
                activeStartDate: activeStartDate
            )
            if viewModel.errorMessage == nil {
                toastCoordinator.show(icon: "calendar.badge.plus", message: "Schedule created", style: .success)
            }
            newScheduleName = ""
            newScheduleEnabled = true
            newScheduleFrequency = .daily
            newScheduleInterval = 1
            newScheduleWeekdays = [2]
            newScheduleMonthDay = 1
            newScheduleStartDate = Date()
        }
    }

    // MARK: - Notifications Tab

    @State private var notificationsLoaded = false

    /// Notification row model for the table display
    struct NotificationDisplayRow: Identifiable, Hashable {
        let id: String
        let type: String
        let target: String
        let level: String
    }

    private var currentNotificationRows: [NotificationDisplayRow] {
        guard let props = viewModel.properties else { return [] }
        var rows: [NotificationDisplayRow] = []
        if props.notifyLevelEmail > 0, let op = props.notifyEmailOperator, !op.isEmpty {
            rows.append(NotificationDisplayRow(id: "email", type: "Email", target: op, level: notifyLevelName(props.notifyLevelEmail)))
        }
        if props.notifyLevelEventlog > 0 {
            rows.append(NotificationDisplayRow(id: "eventlog", type: "Event Log", target: "Windows Application Log", level: notifyLevelName(props.notifyLevelEventlog)))
        }
        return rows
    }

    private var notificationsTab: some View {
        VSplitView {
            let rows = currentNotificationRows
            Table(of: NotificationDisplayRow.self) {
                TableColumn("Type", value: \.type)
                TableColumn("Target", value: \.target)
                TableColumn("When", value: \.level)
            } rows: {
                ForEach(rows) { row in
                    TableRow(row)
                }
            }
            .frame(minHeight: 60)

            notificationEditForm
                .frame(minHeight: 100)
        }
        .onAppear { syncNotificationFields() }
        .onChange(of: viewModel.properties) { _, _ in syncNotificationFields() }
    }

    private func syncNotificationFields() {
        guard !notificationsLoaded, let props = viewModel.properties else { return }
        notifyLevel = props.notifyLevelEmail
        notifyOperator = props.notifyEmailOperator ?? ""
        notifyEventLogLevel = props.notifyLevelEventlog
        notificationsLoaded = true
    }

    private var notificationEditForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Email Notification")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.secondary)

                if viewModel.operators.isEmpty {
                    TextField("Operator", text: $notifyOperator, prompt: Text("e.g. DBA Team"))
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker("Operator", selection: $notifyOperator) {
                        Text("None").tag("")
                        ForEach(viewModel.operators) { op in
                            HStack {
                                Text(op.name)
                                if let email = op.emailAddress, !email.isEmpty {
                                    Text("(\(email))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(op.name)
                        }
                    }
                }

                Picker("Notify when", selection: $notifyLevel) {
                    Text("Never").tag(0)
                    Text("On success").tag(1)
                    Text("On failure").tag(2)
                    Text("On completion").tag(3)
                }

                Divider()

                Text("Windows Event Log")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Write to event log", selection: $notifyEventLogLevel) {
                    Text("Never").tag(0)
                    Text("On success").tag(1)
                    Text("On failure").tag(2)
                    Text("On completion").tag(3)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Save") {
                        Task {
                            await viewModel.setNotification(
                                operatorName: notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines),
                                level: notifyLevel,
                                eventLogLevel: notifyEventLogLevel
                            )
                            if viewModel.errorMessage == nil {
                                toastCoordinator.show(icon: "bell.fill", message: "Notification saved", style: .success)
                                await viewModel.loadDetails()
                                if let props = viewModel.properties {
                                    notifyLevel = props.notifyLevelEmail
                                    notifyOperator = props.notifyEmailOperator ?? ""
                                    notifyEventLogLevel = props.notifyLevelEventlog
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(notifyLevel > 0 && notifyOperator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    private func notifyLevelName(_ level: Int) -> String {
        switch level {
        case 1: return "On success"
        case 2: return "On failure"
        case 3: return "On completion"
        default: return "Never"
        }
    }

    // MARK: - Command Editor Sheet

    private func commandEditorSheet(context: CommandEditorContext) -> some View {
        CommandEditorView(
            context: context,
            onSaveToStep: { stepName, text in
                Task {
                    await viewModel.updateStep(stepName: stepName, newCommand: text, database: nil)
                    commandEditorContext = nil
                }
            },
            onUseCommand: { text in
                newStepCommand = text
                commandEditorContext = nil
            },
            onCancel: {
                commandEditorContext = nil
            }
        )
    }

    // MARK: - Helpers

    private func frequencyDisplayName(_ freqType: Int) -> String {
        switch freqType {
        case 1: return "Once"
        case 4: return "Daily"
        case 8: return "Weekly"
        case 16: return "Monthly"
        case 32: return "Monthly (relative)"
        case 64: return "Agent start"
        case 128: return "Idle"
        default: return "Unknown (\(freqType))"
        }
    }
}

// MARK: - Command Editor Context

struct CommandEditorContext: Identifiable {
    let id = UUID()
    let stepName: String?
    let initialText: String
}

// MARK: - Command Editor View

private struct CommandEditorView: View {
    let context: CommandEditorContext
    let onSaveToStep: (String, String) -> Void
    let onUseCommand: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String

    init(context: CommandEditorContext, onSaveToStep: @escaping (String, String) -> Void, onUseCommand: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.context = context
        self.onSaveToStep = onSaveToStep
        self.onUseCommand = onUseCommand
        self.onCancel = onCancel
        self._text = State(initialValue: context.initialText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.stepName != nil ? "Edit Command — \(context.stepName!)" : "Edit Command")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                if let stepName = context.stepName {
                    Button("Save to Step") {
                        onSaveToStep(stepName, text)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Use Command") {
                        onUseCommand(text)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(SpacingTokens.sm)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Schedule Frequency

enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: return "One Time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var freqType: Int {
        switch self {
        case .once: return 1
        case .daily: return 4
        case .weekly: return 8
        case .monthly: return 16
        }
    }
}
