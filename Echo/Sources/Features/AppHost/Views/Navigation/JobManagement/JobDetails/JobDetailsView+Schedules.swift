import SwiftUI

extension JobDetailsView {

    // MARK: - Schedules Tab

    var schedulesTab: some View {
        VStack(spacing: 0) {
            SchedulesTableView(viewModel: viewModel, selectedScheduleID: $selectedScheduleID) { editingSchedule = $0 }
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
            ) { result in
                let fields = AgentJobScheduleFields(result: result)
                Task {
                    await viewModel.addAndAttachSchedule(
                        name: result.name,
                        enabled: result.enabled,
                        freqType: fields.freqType,
                        freqInterval: fields.freqInterval,
                        activeStartTime: fields.activeStartTime,
                        freqRecurrenceFactor: fields.freqRecurrenceFactor,
                        activeStartDate: fields.activeStartDate,
                        activeEndDate: fields.activeEndDate == AgentJobScheduleFields.noEndDate ? nil : fields.activeEndDate
                    )
                    showAddScheduleSheet = false
                }
            } onCancel: {
                showAddScheduleSheet = false
            }
        }
        .sheet(item: $editingSchedule) { schedule in
            AgentJobScheduleEditorSheet(
                title: "Edit Schedule",
                actionLabel: "Save",
                initial: ScheduleEditorInitialValues(schedule: schedule) ?? ScheduleEditorInitialValues()
            ) { result in
                Task {
                    await viewModel.updateSchedule(originalName: schedule.name, name: result.name, enabled: result.enabled,
                                                   fields: AgentJobScheduleFields(result: result))
                    editingSchedule = nil
                }
            } onCancel: {
                editingSchedule = nil
            }
        }
    }
}

// MARK: - Sortable Schedules Table

private struct SchedulesTableView: View {
    var viewModel: JobQueueViewModel
    @Binding var selectedScheduleID: Set<String>
    let onEdit: (JobQueueViewModel.ScheduleRow) -> Void
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
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .tableColumnAutoResize()
        // A double-click (or Return) on a schedule opens Edit Schedule.
        .contextMenu(forSelectionType: String.self) { items in
            if let id = items.first, let sch = viewModel.schedules.first(where: { $0.id == id }) {
                Button {
                    onEdit(sch)
                } label: {
                    Label("Edit Schedule", systemImage: "pencil")
                }
                .disabled(ScheduleEditorInitialValues(schedule: sch) == nil)
                .help(ScheduleEditorInitialValues(schedule: sch) == nil ? "This kind of schedule can't be edited in Echo yet" : "")
                Divider()
                Button("Detach Schedule", role: .destructive) {
                    pendingDetachName = sch.name
                    showDetachAlert = true
                }
            }
        } primaryAction: { items in
            if let id = items.first, let sch = viewModel.schedules.first(where: { $0.id == id }),
               ScheduleEditorInitialValues(schedule: sch) != nil {
                onEdit(sch)
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
