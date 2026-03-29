import SwiftUI
import SQLServerKit

// MARK: - Advanced Page

extension ServerEditorView {

    @ViewBuilder
    func advancedPage() -> some View {
        let standard = viewModel.configurations.filter { !$0.isAdvanced }
        let advanced = viewModel.configurations.filter { $0.isAdvanced }

        if !standard.isEmpty {
            Section("Standard Options") {
                ForEach(standard) { option in
                    configOptionRow(option)
                }
            }
        }

        if !advanced.isEmpty {
            Section("Advanced Options") {
                ForEach(advanced) { option in
                    configOptionRow(option)
                }
            }
        }
    }

    // MARK: - Option Row

    private func configOptionRow(_ option: SQLServerConfigurationOption) -> some View {
        PropertyRow(
            title: option.name,
            subtitle: "Range: \(option.minimum)–\(option.maximum)"
        ) {
            HStack(spacing: SpacingTokens.xs) {
                TextField("", value: configValueBinding(for: option.name), format: .number, prompt: Text("0"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)

                if option.isPendingRestart || (viewModel.pendingChanges[option.name] != nil && !option.isDynamic) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(ColorTokens.Status.warning)
                        .help("Requires SQL Server restart")
                }
            }
        }
    }
}
