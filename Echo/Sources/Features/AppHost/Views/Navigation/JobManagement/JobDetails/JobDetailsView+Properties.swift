import SwiftUI

extension JobDetailsView {

    // MARK: - Properties Tab

    var propertiesTab: some View {
        let props = editingProps ?? viewModel.properties ?? JobQueueViewModel.PropertySheet(
            name: "", description: nil, owner: nil, category: nil, enabled: false, startStepId: nil
        )
        let boundProps = Binding<JobQueueViewModel.PropertySheet>(
            get: { editingProps ?? viewModel.properties ?? props },
            set: { editingProps = $0 }
        )

        return Form {
            Section("General") {
                TextField("Name", text: boundProps.name, prompt: Text("job_name"))

                Toggle("Enabled", isOn: boundProps.enabled)

                LabeledContent("Description") {
                    TextField("", text: Binding(
                        get: { boundProps.wrappedValue.description ?? "" },
                        set: { boundProps.wrappedValue.description = $0 }
                    ), prompt: Text("Job description"), axis: .vertical)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
                }
            }

            Section("Ownership") {
                if viewModel.logins.isEmpty {
                    LabeledContent("Owner") {
                        TextField("", text: Binding(
                            get: { boundProps.wrappedValue.owner ?? "" },
                            set: { boundProps.wrappedValue.owner = $0 }
                        ), prompt: Text("sa"))
                        .multilineTextAlignment(.trailing)
                    }
                } else {
                    Picker("Owner", selection: Binding(
                        get: { boundProps.wrappedValue.owner ?? "" },
                        set: { boundProps.wrappedValue.owner = $0 }
                    )) {
                        ForEach(viewModel.logins, id: \.self) { login in
                            Text(login).tag(login)
                        }
                    }
                }

                if viewModel.categories.isEmpty {
                    LabeledContent("Category") {
                        TextField("", text: Binding(
                            get: { boundProps.wrappedValue.category ?? "" },
                            set: { boundProps.wrappedValue.category = $0 }
                        ), prompt: Text("Maintenance"))
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
                            .foregroundStyle(ColorTokens.Text.secondary)
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
                                    notificationEngine?.post(category: .jobPropertiesSaved, message: "Properties saved")
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
}
