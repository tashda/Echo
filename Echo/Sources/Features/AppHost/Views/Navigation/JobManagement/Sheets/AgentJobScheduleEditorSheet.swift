import SwiftUI

/// Shared sheet for creating a schedule for an Agent Job.
/// Used by both the "New Job" modal and the "Details" pane.
struct AgentJobScheduleEditorSheet: View {
    @State var name: String = ""
    @State var enabled: Bool = true
    @State var frequency: ScheduleFrequency = .daily
    @State var interval: Int = 1
    @State var startHour: Int = 9
    @State var startMinute: Int = 0
    @State var weekdays: Set<Int> = [2]
    @State var monthDay: Int = 1
    @State var startDate: Date = Date()
    @State var oneTimeDate: Date = Date()
    @State var useActiveWindow: Bool = false
    @State var activeStartDate: Date = Date()
    @State var activeEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State var activeStartHour: Int = 0
    @State var activeStartMinute: Int = 0
    @State var activeEndHour: Int = 23
    @State var activeEndMinute: Int = 59

    let title: String
    let actionLabel: String
    let onSave: (ScheduleEditorResult) -> Void
    let onCancel: () -> Void

    init(
        title: String = "New Schedule",
        actionLabel: String = "Create Schedule",
        onSave: @escaping (ScheduleEditorResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.actionLabel = actionLabel
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(title) {
                    TextField("Name", text: $name, prompt: Text("e.g. Daily 9 AM"))
                    Toggle("Enabled", isOn: $enabled)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section("Recurrence") {
                    frequencyOptions
                    timeSection
                }

                if frequency != .once {
                    Section {
                        DatePicker("Starting from", selection: $startDate, displayedComponents: .date)
                    }

                    Section("Active Window") {
                        Toggle("Limit active window", isOn: $useActiveWindow)
                            .toggleStyle(.switch)
                        if useActiveWindow {
                            DatePicker("Start date", selection: $activeStartDate, displayedComponents: .date)
                            activeTimePicker(label: "Start time", hour: $activeStartHour, minute: $activeStartMinute)
                            DatePicker("End date", selection: $activeEndDate, displayedComponents: .date)
                            activeTimePicker(label: "End time", hour: $activeEndHour, minute: $activeEndMinute)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(actionLabel) {
                    onSave(ScheduleEditorResult(
                        name: name, enabled: enabled, frequency: frequency,
                        interval: interval, startHour: startHour, startMinute: startMinute,
                        weekdays: weekdays, monthDay: monthDay, startDate: startDate,
                        oneTimeDate: oneTimeDate, useActiveWindow: useActiveWindow,
                        activeStartDate: activeStartDate, activeEndDate: activeEndDate,
                        activeStartHour: activeStartHour, activeStartMinute: activeStartMinute,
                        activeEndHour: activeEndHour, activeEndMinute: activeEndMinute
                    ))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(SpacingTokens.md2)
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    @ViewBuilder
    private var frequencyOptions: some View {
        switch frequency {
        case .daily:
            Stepper("Every \(interval) day(s)", value: $interval, in: 1...365)
        case .weekly:
            Stepper("Every \(interval) week(s)", value: $interval, in: 1...52)
            weekdayToggles
        case .monthly:
            Stepper("Every \(interval) month(s)", value: $interval, in: 1...12)
            Stepper("On day \(monthDay) of the month", value: $monthDay, in: 1...31)
        case .once:
            DatePicker("Run on", selection: $oneTimeDate, displayedComponents: .date)
        }
    }

    private var timeSection: some View {
        HStack {
            Text("At")
            Picker("Hour", selection: $startHour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d", h)).tag(h) }
            }
            .frame(width: 70)
            .labelsHidden()
            Text(":")
            Picker("Minute", selection: $startMinute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 70)
            .labelsHidden()
        }
    }

    private func activeTimePicker(label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("Hour", selection: hour) {
                ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d", h)).tag(h) }
            }
            .frame(width: 70)
            .labelsHidden()
            Text(":")
            Picker("Minute", selection: minute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 70)
            .labelsHidden()
        }
    }

    private var weekdayToggles: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach([(1, "Sun"), (2, "Mon"), (4, "Tue"), (8, "Wed"), (16, "Thu"), (32, "Fri"), (64, "Sat")], id: \.0) { value, label in
                Toggle(label, isOn: Binding(
                    get: { weekdays.contains(value) },
                    set: { on in
                        if on { weekdays.insert(value) } else { weekdays.remove(value) }
                    }
                ))
                .toggleStyle(.button)
                .controlSize(.small)
            }
        }
    }
}
