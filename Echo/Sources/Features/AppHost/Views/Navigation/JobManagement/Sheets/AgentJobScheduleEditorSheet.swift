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

    let title: String
    let actionLabel: String
    let onSave: (String, Bool, ScheduleFrequency, Int, Int, Int, Set<Int>, Int, Date, Date) -> Void
    let onCancel: () -> Void

    init(
        title: String = "New Schedule",
        actionLabel: String = "Create Schedule",
        onSave: @escaping (String, Bool, ScheduleFrequency, Int, Int, Int, Set<Int>, Int, Date, Date) -> Void,
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
                    onSave(name, enabled, frequency, interval, startHour, startMinute, weekdays, monthDay, startDate, oneTimeDate)
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
