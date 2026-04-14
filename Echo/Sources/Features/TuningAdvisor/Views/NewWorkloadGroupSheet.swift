import SwiftUI
import SQLServerKit

struct NewWorkloadGroupSheet: View {
    let viewModel: ResourceGovernorViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var selectedPool = "default"
    @State private var importance = "MEDIUM"
    @State private var maxMemoryGrant = 25
    @State private var maxCpuTime = 0
    @State private var maxDop = 0
    @State private var maxRequests = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private var poolNames: [String] {
        viewModel.pools.map(\.name).filter { $0 != "internal" }
    }

    var body: some View {
        SheetLayout(
            title: "New Workload Group",
            icon: "cpu",
            subtitle: "Create a Resource Governor workload group.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("New Workload Group") {
                    PropertyRow(title: "Group Name") {
                        TextField("", text: $name, prompt: Text("e.g. ReportingGroup"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    PropertyRow(title: "Resource Pool") {
                        Picker("", selection: $selectedPool) {
                            ForEach(poolNames, id: \.self) { pool in
                                Text(pool).tag(pool)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    PropertyRow(title: "Importance") {
                        Picker("", selection: $importance) {
                            Text("Low").tag("LOW")
                            Text("Medium").tag("MEDIUM")
                            Text("High").tag("HIGH")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                Section("Limits") {
                    PropertyRow(title: "Max Memory Grant %") {
                        Stepper("\(maxMemoryGrant)%", value: $maxMemoryGrant, in: 1...100)
                    }
                    PropertyRow(title: "Max CPU Time (sec)") {
                        Stepper("\(maxCpuTime)", value: $maxCpuTime, in: 0...86400)
                    }
                    PropertyRow(title: "Max DOP") {
                        Stepper("\(maxDop)", value: $maxDop, in: 0...128)
                    }
                    PropertyRow(title: "Max Requests") {
                        Stepper("\(maxRequests)", value: $maxRequests, in: 0...10000)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 400)
    }

    private func submit() async {
        let groupName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupName.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        await viewModel.createGroup(name: groupName, poolName: selectedPool, importance: importance, maxMemGrant: maxMemoryGrant, maxCpuTime: maxCpuTime, maxDop: maxDop, maxRequests: maxRequests)
        if viewModel.errorMessage == nil {
            onComplete()
        } else {
            errorMessage = viewModel.errorMessage
            isSubmitting = false
        }
    }
}
