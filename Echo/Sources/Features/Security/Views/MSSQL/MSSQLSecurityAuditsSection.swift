import SwiftUI
import SQLServerKit

struct MSSQLSecurityAuditsSection: View {
    @Bindable var viewModel: ServerSecurityViewModel
    var onNewAudit: () -> Void
    @Environment(EnvironmentState.self) private var environmentState

    @State private var sortOrder = [KeyPathComparator(\ServerAuditInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    private var sortedAudits: [ServerAuditInfo] {
        viewModel.audits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedAudits, selection: $viewModel.selectedAuditName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { audit in
                Text(audit.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Enabled") { audit in
                Image(systemName: audit.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(audit.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(min: 50, ideal: 70)

            TableColumn("Destination") { audit in
                Text(audit.destination.displayName)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("On Failure") { audit in
                Text(audit.onFailure.displayName)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("File Path") { audit in
                if let path = audit.filePath, !path.isEmpty {
                    Text(path)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 200)

            TableColumn("Created") { audit in
                if let date = audit.createDate {
                    Text(date)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: String.self) { selection in
            if let name = selection.first,
               let audit = viewModel.audits.first(where: { $0.name == name }) {
                Button {
                    Task { await viewModel.toggleAudit(name, enabled: !audit.isEnabled) }
                } label: {
                    Label(audit.isEnabled ? "Disable" : "Enable", systemImage: audit.isEnabled ? "pause.circle" : "play.circle")
                }

                Divider()

                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(name: name) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(name: name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropName = name
                    showDropAlert = true
                } label: {
                    Label("Drop Audit", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewAudit() } label: {
                    Label("New Audit", systemImage: "shield.lefthalf.filled.badge.checkmark")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Server Audit?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropAudit(name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the server audit \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func scriptCreate(name: String) {
        let n = escapeID(name)
        openScriptTab(sql: "CREATE SERVER AUDIT \(n)\n    TO FILE (FILEPATH = N'C:\\AuditFiles\\')\n    WITH (ON_FAILURE = CONTINUE);\nGO")
    }

    private func scriptDrop(name: String) {
        openScriptTab(sql: "DROP SERVER AUDIT \(escapeID(name));\nGO")
    }

    private func escapeID(_ name: String) -> String {
        "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private func openScriptTab(sql: String) {
        if let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) {
            environmentState.openQueryTab(for: session, presetQuery: sql)
        }
    }
}
