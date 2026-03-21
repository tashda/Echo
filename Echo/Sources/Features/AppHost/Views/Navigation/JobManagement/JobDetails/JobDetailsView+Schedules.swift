import SwiftUI

extension JobDetailsView {

    // MARK: - Schedules Tab

    var schedulesTab: some View {
        VStack(spacing: 0) {
            SchedulesTableView(viewModel: viewModel, selectedScheduleID: $selectedScheduleID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if viewModel.schedules.isEmpty {
                        Text("No schedules defined.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }

            Divider()

            HStack {
                Spacer()
                Button {
                    showAddScheduleSheet = true
                } label: {
                    Label("New Schedule", systemImage: "plus")
                }
                .controlSize(.small)
                .padding(SpacingTokens.xs)
            }
        }
        .sheet(isPresented: $showAddScheduleSheet) {
            AgentJobScheduleEditorSheet(
                title: "New Schedule",
                actionLabel: "Create Schedule"
            ) { name, enabled, frequency, interval, startHour, startMinute, weekdays, monthDay, startDate, oneTimeDate in
                let freqType: Int
                let freqInterval: Int
                let activeStartTime: Int? = startHour * 10000 + startMinute * 100
                var freqRecurrenceFactor: Int? = nil
                var activeStartDate: Int? = nil

                switch frequency {
                case .daily:
                    freqType = 4; freqInterval = interval
                case .weekly:
                    freqType = 8; freqInterval = weekdays.reduce(0, |); freqRecurrenceFactor = interval
                case .monthly:
                    freqType = 16; freqInterval = monthDay; freqRecurrenceFactor = interval
                case .once:
                    freqType = 1; freqInterval = 0
                    let comps = Calendar.current.dateComponents([.year, .month, .day], from: oneTimeDate)
                    activeStartDate = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
                }

                Task {
                    await viewModel.addAndAttachSchedule(
                        name: name,
                        enabled: enabled,
                        freqType: freqType,
                        freqInterval: freqInterval,
                        activeStartTime: activeStartTime,
                        freqRecurrenceFactor: freqRecurrenceFactor,
                        activeStartDate: activeStartDate
                    )
                    showAddScheduleSheet = false
                }
            } onCancel: {
                showAddScheduleSheet = false
            }
        }
    }
}

// MARK: - Sortable Schedules Table

private struct SchedulesTableView: View {
    var viewModel: JobQueueViewModel
    @Binding var selectedScheduleID: Set<String>
    @State private var sortOrder: [KeyPathComparator<JobQueueViewModel.ScheduleRow>] = [
        .init(\.name, order: .forward)
    ]
    @State private var showDetachAlert = false
    @State private var pendingDetachName: String?

    private var sortedSchedules: [JobQueueViewModel.ScheduleRow] {
        viewModel.schedules.sorted(using: sortOrder)
    }

    var body: some View {
        Table(of: JobQueueViewModel.ScheduleRow.self, selection: $selectedScheduleID, sortOrder: $sortOrder) {
            TableColumn("Enabled", value: \.enabledSortKey) { sch in
                Image(systemName: sch.enabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(sch.enabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
            }
            .width(24)

            TableColumn("Name", value: \.name) { sch in
                Text(sch.name)
                    .font(TypographyTokens.Table.name)
            }

            TableColumn("Frequency", value: \.freqType) { sch in
                Text(frequencyDisplayName(sch.freqType))
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            TableColumn("Next Run", value: \.nextSortKey) { sch in
                if let next = sch.next {
                    Text(next)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        } rows: {
            ForEach(sortedSchedules) { sch in
                TableRow(sch)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { items in
            if let id = items.first, let sch = viewModel.schedules.first(where: { $0.id == id }) {
                Button("Detach Schedule", role: .destructive) {
                    pendingDetachName = sch.name
                    showDetachAlert = true
                }
            }
        }
        .alert("Detach Schedule?", isPresented: $showDetachAlert) {
            Button("Cancel", role: .cancel) { pendingDetachName = nil }
            Button("Detach", role: .destructive) {
                guard let name = pendingDetachName else { return }
                pendingDetachName = nil
                Task { await viewModel.detachSchedule(scheduleName: name) }
            }
        } message: {
            if let name = pendingDetachName {
                Text("Are you sure you want to detach schedule \"\(name)\" from this job?")
            }
        }
    }

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
