import SwiftUI

struct JobDetailsView: View {
    @ObservedObject var viewModel: JobQueueViewModel

    // Properties editing
    @Binding var editingProps: JobQueueViewModel.PropertySheet?
    // Step editing
    @Binding var newStepName: String
    @Binding var newStepDatabase: String
    @Binding var newStepCommand: String
    @Binding var selectedStepID: Int?
    @Binding var editStepName: String
    @Binding var editStepDatabase: String
    @Binding var editStepCommand: String
    // Schedule editing
    @Binding var newScheduleName: String
    @Binding var newScheduleEnabled: Bool
    @Binding var newScheduleFreqType: Int
    @Binding var newScheduleFreqInterval: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.headline).padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.xxs2)
            if let props = viewModel.properties {
                let boundProps = Binding<JobQueueViewModel.PropertySheet>(
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
                    .padding(.horizontal, SpacingTokens.sm)
                    .tabItem { Text("Properties") }

                    // Steps tab (add/edit/delete)
                    VStack(alignment: .leading) {
                        Table(of: JobQueueViewModel.StepRow.self, selection: Binding(get: {
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

                        Divider().padding(.vertical, SpacingTokens.xxs)

                        Text("Add Step").font(.subheadline)
                        HStack { TextField("Name", text: $newStepName); TextField("Database (optional)", text: $newStepDatabase) }
                        TextField("Command", text: $newStepCommand, axis: .vertical)
                        HStack { Button("Add") { Task { await viewModel.addTSQLStep(name: newStepName, database: newStepDatabase.isEmpty ? nil : newStepDatabase, command: newStepCommand); newStepName = ""; newStepDatabase = ""; newStepCommand = "" } }; Spacer() }

                        if let sid = selectedStepID, let step = viewModel.steps.first(where: { $0.id == sid }) {
                            Divider().padding(.vertical, SpacingTokens.xxs)
                            Text("Edit Step #\(sid)").font(.subheadline)
                            HStack { TextField("Name", text: Binding(get: { editStepName.isEmpty ? step.name : editStepName }, set: { editStepName = $0 })); TextField("Database (optional)", text: Binding(get: { editStepDatabase.isEmpty ? (step.database ?? "") : editStepDatabase }, set: { editStepDatabase = $0 })) }
                            TextField("Command", text: Binding(get: { editStepCommand.isEmpty ? (step.command ?? "") : editStepCommand }, set: { editStepCommand = $0 }), axis: .vertical)
                            HStack {
                                Button("Update") { Task { await viewModel.updateTSQLStep(stepID: sid, name: editStepName.isEmpty ? step.name : editStepName, database: (editStepDatabase.isEmpty ? step.database : editStepDatabase), command: editStepCommand.isEmpty ? (step.command ?? "") : editStepCommand); editStepName = ""; editStepDatabase = ""; editStepCommand = "" } }
                                Button("Delete", role: .destructive) { Task { await viewModel.deleteStep(stepID: sid); selectedStepID = nil; editStepName = ""; editStepDatabase = ""; editStepCommand = "" } }
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .tabItem { Text("Steps") }

                    // Schedules tab (attach/detach)
                    VStack(alignment: .leading) {
                        Table(of: JobQueueViewModel.ScheduleRow.self) {
                            TableColumn("Name", value: \.name)
                            TableColumn("Enabled") { sch in Image(systemName: sch.enabled ? "checkmark.circle" : "xmark.circle").foregroundStyle(sch.enabled ? .green : .secondary) }.width(28)
                            TableColumn("Frequency") { sch in Text("\(sch.freqType)") }
                            TableColumn("Next Run") { sch in Text(sch.next ?? "—").foregroundStyle(.secondary) }
                        } rows: {
                            ForEach(viewModel.schedules) { sch in TableRow(sch).contextMenu { Button("Detach") { Task { await viewModel.detachSchedule(scheduleID: sch.id) } } } }
                        }
                        .frame(maxHeight: 220)

                        Divider().padding(.vertical, SpacingTokens.xxs)
                        Text("Add Schedule").font(.subheadline)
                        HStack { TextField("Name", text: $newScheduleName); Toggle("Enabled", isOn: $newScheduleEnabled) }
                        HStack { TextField("Freq Type (4=Daily)", value: $newScheduleFreqType, formatter: NumberFormatter()); TextField("Freq Interval", value: $newScheduleFreqInterval, formatter: NumberFormatter()) }
                        Button("Create & Attach") { Task { await viewModel.addAndAttachSchedule(name: newScheduleName, enabled: newScheduleEnabled, freqType: newScheduleFreqType, freqInterval: newScheduleFreqInterval); newScheduleName = ""; newScheduleEnabled = true } }
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .tabItem { Text("Schedules") }

                    // Notifications (placeholder)
                    VStack(alignment: .leading) {
                        Text("Job-level notifications are displayed in Properties.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .tabItem { Text("Notifications") }
                }
                .tabViewStyle(.automatic)
            } else {
                Text("Select a job to view details.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SpacingTokens.sm)
            }
            Spacer()
        }
    }
}
