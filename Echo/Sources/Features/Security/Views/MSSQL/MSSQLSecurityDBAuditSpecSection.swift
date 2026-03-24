import SwiftUI
import SQLServerKit

struct MSSQLSecurityDBAuditSpecSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    var onNewSpec: () -> Void
    @Environment(EnvironmentState.self) private var environmentState

    @State private var sortOrder = [KeyPathComparator(\AuditSpecificationInfo.name)]
    @State private var showDropAlert = false
    @State private var pendingDropName: String?

    private var sortedSpecs: [AuditSpecificationInfo] {
        viewModel.dbAuditSpecs.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedSpecs, selection: $viewModel.selectedDBAuditSpecName, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { spec in
                Text(spec.name)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Audit", value: \.auditName) { spec in
                Text(spec.auditName)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Enabled") { spec in
                Image(systemName: spec.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(spec.isEnabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(min: 50, ideal: 70)

            TableColumn("Created") { spec in
                if let date = spec.createDate {
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
               let spec = viewModel.dbAuditSpecs.first(where: { $0.name == name }) {
                Button {
                    Task { await viewModel.toggleDBAuditSpec(name: spec.name, enabled: !spec.isEnabled) }
                } label: {
                    Label(spec.isEnabled ? "Disable" : "Enable", systemImage: spec.isEnabled ? "pause.circle" : "play.circle")
                }

                Divider()

                Menu("Script as", systemImage: "scroll") {
                    Button { scriptCreate(spec) } label: {
                        Label("CREATE", systemImage: "plus.square")
                    }
                    Button { scriptDrop(name: spec.name) } label: {
                        Label("DROP", systemImage: "minus.square")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    pendingDropName = name
                    showDropAlert = true
                } label: {
                    Label("Drop Audit Specification", systemImage: "trash")
                }
            } else {
                Button {
                    Task { await viewModel.loadCurrentSection() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button { onNewSpec() } label: {
                    Label("New Audit Specification", systemImage: "plus")
                }
            }
        } primaryAction: { _ in }
        .alert("Drop Database Audit Specification?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = pendingDropName {
                    Task { await viewModel.dropDBAuditSpec(name: name) }
                }
            }
        } message: {
            Text("Are you sure you want to drop the audit specification \(pendingDropName ?? "")? This action cannot be undone.")
        }
    }

    private func scriptCreate(_ spec: AuditSpecificationInfo) {
        let n = escapeID(spec.name)
        let a = escapeID(spec.auditName)
        openScriptTab(sql: "CREATE DATABASE AUDIT SPECIFICATION \(n)\n    FOR SERVER AUDIT \(a)\n    ADD (SELECT ON SCHEMA::dbo BY public);\nGO")
    }

    private func scriptDrop(name: String) {
        let n = escapeID(name)
        openScriptTab(sql: "DROP DATABASE AUDIT SPECIFICATION \(n);\nGO")
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
