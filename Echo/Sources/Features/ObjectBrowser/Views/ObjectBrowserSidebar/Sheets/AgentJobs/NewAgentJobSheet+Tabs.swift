import SwiftUI
import SQLServerKit

// MARK: - Steps, Schedules, Notifications Tabs

extension NewAgentJobSheet {

    // MARK: - Steps Tab

    var stepsTab: some View {
        Form {
            if steps.isEmpty {
                Section {
                    Text("No steps added yet. Add a step to define what this job does.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                Section("Step \(index + 1)") {
                    TextField("Name", text: $steps[index].name, prompt: Text("e.g. Run cleanup query"))
                    Picker("Type", selection: $steps[index].subsystem) {
                        Text("T-SQL").tag(SubsystemChoice.tsql)
                        Text("CmdExec").tag(SubsystemChoice.cmdExec)
                        Text("PowerShell").tag(SubsystemChoice.powershell)
                    }
                    if steps[index].subsystem == .tsql {
                        Picker("Database", selection: $steps[index].database) {
                            Text("Default").tag("")
                            ForEach(databaseNames, id: \.self) { db in
                                Text(db).tag(db)
                            }
                        }
                    }

                    LabeledContent("Command") {
                        TextEditor(text: $steps[index].command)
                            .font(TypographyTokens.body.monospaced())
                            .frame(minHeight: 60, maxHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(SpacingTokens.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(ColorTokens.Background.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(ColorTokens.Text.quaternary.opacity(0.4), lineWidth: 0.5)
                            )
                    }

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

    var schedulesTab: some View {
        Form {
            if schedules.isEmpty {
                Section {
                    Text("No schedules added yet. Add a schedule to run this job automatically.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            ForEach(Array(schedules.enumerated()), id: \.element.id) { index, _ in
                Section(schedules[index].name.isEmpty ? "Schedule \(index + 1)" : schedules[index].name) {
                    TextField("Name", text: $schedules[index].name, prompt: Text("e.g. Daily 9 AM"))
                    Toggle("Enabled", isOn: $schedules[index].enabled)
                    Picker("Frequency", selection: $schedules[index].mode) {
                        ForEach(ScheduleModeChoice.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    scheduleFrequencyOptions(index: index)

                    if schedules[index].mode != .once {
                        activeWindowSection(index: index)
                    }

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
    func scheduleFrequencyOptions(index: Int) -> some View {
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
    func weekdayToggles(index: Int) -> some View {
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

    @ViewBuilder
    func activeWindowSection(index: Int) -> some View {
        Toggle("Limit active window", isOn: $schedules[index].useActiveWindow)
        if schedules[index].useActiveWindow {
            DatePicker("Active start date", selection: $schedules[index].activeStartDate, displayedComponents: .date)
            DatePicker("Active end date", selection: $schedules[index].activeEndDate, displayedComponents: .date)
        }
    }

    func scheduleSummary(for entry: ScheduleEntry) -> some View {
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

    func ordinal(_ n: Int) -> String {
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

    var notificationsTab: some View {
        Form {
            Section("Email Notification") {
                TextField("Operator name", text: $notifyOperator, prompt: Text("e.g. DBA_Team"))
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
}
