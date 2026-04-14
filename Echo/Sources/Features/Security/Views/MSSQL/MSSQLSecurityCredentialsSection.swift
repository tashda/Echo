import SwiftUI
import SQLServerKit

struct MSSQLSecurityCredentialsSection: View {
    @Bindable var viewModel: ServerSecurityViewModel
    var onNewCredential: () -> Void
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    var body: some View {
        Table(viewModel.credentials, selection: $viewModel.selectedCredentialName) {
            TableColumn("Name") { cred in
                Text(cred.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Identity") { cred in
                if let identity = cred.identity, !identity.isEmpty {
                    Text(identity)
                        .font(TypographyTokens.Table.secondaryName)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 120, ideal: 200)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first {
                // Group 6: Script as
                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(name: name) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(name: name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                // Group 9: Destructive
                Button(role: .destructive) {
                    pendingDropName = name
                    showDropAlert = true
                } label: {
                    Label("Drop Credential", systemImage: "trash")
                }
            } else {
                // Empty-space menu
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewCredential() } label: {
                    Label("New Credential", systemImage: "key.fill")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Credential?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropCredential(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the credential \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func scriptCreate(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "CREATE CREDENTIAL \(escaped)\nWITH IDENTITY = N'<identity>',\n     SECRET = N'<secret>';\nGO")
    }

    private func scriptDrop(name: String) {
        let escaped = "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        openScriptTab(sql: "DROP CREDENTIAL \(escaped);\nGO")
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
