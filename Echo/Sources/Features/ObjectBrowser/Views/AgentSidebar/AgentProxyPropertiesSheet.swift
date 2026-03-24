import SwiftUI

/// Displays read-only properties for a SQL Server Agent proxy.
struct AgentProxyPropertiesSheet: View {
    let proxy: AgentSidebarViewModel.AgentProxy
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Proxy Properties") {
                    LabeledContent("Name", value: proxy.name)
                    LabeledContent("Status", value: proxy.enabled ? "Enabled" : "Disabled")
                    LabeledContent("Credential", value: proxy.credentialName ?? "None")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(SpacingTokens.md2)
        }
        .frame(minWidth: 340, minHeight: 180)
    }
}
