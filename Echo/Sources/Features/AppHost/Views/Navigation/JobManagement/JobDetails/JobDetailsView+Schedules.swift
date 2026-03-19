import SwiftUI

extension JobDetailsView {

    // MARK: - Schedules Tab

    var schedulesTab: some View {
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
                        Text("\u{2014}").foregroundStyle(ColorTokens.Text.secondary)
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

    var newScheduleForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("New Schedule")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)

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
                    .foregroundStyle(ColorTokens.Text.secondary)

                scheduleRecurrenceContent

                Divider()

                Text("Start Time")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)

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
}
