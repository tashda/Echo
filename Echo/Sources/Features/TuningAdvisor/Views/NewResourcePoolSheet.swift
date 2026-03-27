import SwiftUI

struct NewResourcePoolSheet: View {
    let viewModel: ResourceGovernorViewModel
    let onComplete: () -> Void

    @State private var name = ""
    @State private var minCpu = 0
    @State private var maxCpu = 100
    @State private var minMemory = 0
    @State private var maxMemory = 100
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        SheetLayout(
            title: "New Resource Pool",
            icon: "gauge.with.dots.needle.33percent",
            subtitle: "Create a Resource Governor resource pool.",
            primaryAction: "Create",
            canSubmit: isFormValid,
            isSubmitting: isSubmitting,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { onComplete() }
        ) {
            Form {
                Section("New Resource Pool") {
                    PropertyRow(title: "Pool Name") {
                        TextField("", text: $name, prompt: Text("e.g. ReportingPool"))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("CPU Limits") {
                    PropertyRow(title: "Min CPU %") {
                        Stepper("\(minCpu)%", value: $minCpu, in: 0...100)
                    }
                    PropertyRow(title: "Max CPU %") {
                        Stepper("\(maxCpu)%", value: $maxCpu, in: 0...100)
                    }
                }
                Section("Memory Limits") {
                    PropertyRow(title: "Min Memory %") {
                        Stepper("\(minMemory)%", value: $minMemory, in: 0...100)
                    }
                    PropertyRow(title: "Max Memory %") {
                        Stepper("\(maxMemory)%", value: $maxMemory, in: 0...100)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 340)
    }

    private func submit() async {
        let poolName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !poolName.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        await viewModel.createPool(name: poolName, minCpu: minCpu, maxCpu: maxCpu, minMem: minMemory, maxMem: maxMemory)
        if viewModel.errorMessage == nil {
            onComplete()
        } else {
            errorMessage = viewModel.errorMessage
            isSubmitting = false
        }
    }
}
