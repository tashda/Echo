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
        VStack(spacing: 0) {
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

            Divider()

            HStack(spacing: SpacingTokens.sm) {
                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .lineLimit(1)
                }
                Spacer()
                Button("Cancel") { onComplete() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.sm2)
            .background(.bar)
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 340)
        .navigationTitle("New Resource Pool")
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
