import SwiftUI

// MARK: - Startup Parameters Page

extension ServerEditorView {

    @ViewBuilder
    func startupParametersPage() -> some View {
        let params = viewModel.startupParameters

        if params.isEmpty {
            Section {
                Text("No startup parameters found.")
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        } else {
            Section("Startup Parameters") {
                Text("These parameters are read from the server registry and take effect when the SQL Server instance starts. Changes require a server restart.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)

                ForEach(Array(params.enumerated()), id: \.offset) { index, param in
                    PropertyRow(title: "Parameter \(index + 1)") {
                        Text(param)
                            .font(TypographyTokens.code)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Parameter Reference") {
                parameterReferenceRow("-d", description: "Data file path for the master database")
                parameterReferenceRow("-e", description: "Error log file path")
                parameterReferenceRow("-l", description: "Transaction log file path for the master database")
                parameterReferenceRow("-m", description: "Start in single-user mode")
                parameterReferenceRow("-T", description: "Trace flag (e.g., -T1118, -T3226)")
                parameterReferenceRow("-f", description: "Start with minimal configuration")
                parameterReferenceRow("-g", description: "Memory reserved for non-SQL allocations (MB)")
                parameterReferenceRow("-x", description: "Disable performance monitor counters")
            }
        }
    }

    @ViewBuilder
    private func parameterReferenceRow(_ flag: String, description: String) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text(flag)
                .font(TypographyTokens.code)
                .frame(width: 40, alignment: .leading)
            Text(description)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
