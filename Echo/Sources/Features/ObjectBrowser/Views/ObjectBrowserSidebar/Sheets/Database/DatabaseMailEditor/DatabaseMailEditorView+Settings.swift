import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var settingsSection: some View {
        Section("System Parameters") {
            ForEach(viewModel.configParameters) { param in
                settingsRow(param)
            }
        }
    }

    private func settingsRow(_ param: SQLServerMailConfigParameter) -> some View {
        let binding = settingsBinding(for: param.name)
        return VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            TextField(
                param.name,
                text: binding,
                prompt: Text(param.value)
            )
            if let desc = param.description, !desc.isEmpty {
                Text(desc)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    private func settingsBinding(for name: String) -> Binding<String> {
        Binding(
            get: {
                viewModel.pendingSettings[name] ?? viewModel.configParameters.first { $0.name == name }?.value ?? ""
            },
            set: { newValue in
                viewModel.pendingSettings[name] = newValue
            }
        )
    }
}
