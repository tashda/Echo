import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var settingsPage: some View {
        Group {
            if configParameters.isEmpty {
                mailEmptyState("No configuration parameters available.", icon: "gearshape")
            } else {
                settingsForm
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section("System Parameters") {
                ForEach(configParameters) { param in
                    settingsRow(param)
                }
            }

            Section {
                Button("Apply Changes") {
                    Task { await applySettings() }
                }
                .disabled(isSaving || !hasSettingsChanges)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
                pendingSettings[name] ?? configParameters.first { $0.name == name }?.value ?? ""
            },
            set: { newValue in
                pendingSettings[name] = newValue
            }
        )
    }

    var hasSettingsChanges: Bool {
        for (key, value) in pendingSettings {
            if let original = configParameters.first(where: { $0.name == key }),
               original.value != value {
                return true
            }
        }
        return false
    }
}
