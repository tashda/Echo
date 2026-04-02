import SwiftUI
import PostgresKit

struct PostgresTablespacesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.tablespaces, selection: $selection) {
            TableColumn("Name") { ts in
                Text(ts.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Owner") { ts in
                Text(ts.owner).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Location") { ts in
                Text(ts.location.isEmpty ? "\u{2014}" : ts.location)
                    .font(TypographyTokens.Table.path)
                    .foregroundStyle(ts.location.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
            .width(min: 120, ideal: 300)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Tablespace", objectName: $pendingDropName) { name in
            Task { await viewModel.dropTablespace(name) }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameTablespace(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeTablespaceOwner(edit.objectName, newOwner: newValue)
                case .changeSchema: break
                }
            } onCancel: {
                pendingEdit = nil
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(selection: Set<String>) -> some View {
        if selection.isEmpty {
            Button { onCreate?() } label: {
                Label("New Tablespace", systemImage: "externaldrive")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "TABLESPACE", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                Button {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Tablespace", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "TABLESPACE", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Tablespaces", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresTablespaceInfo: @retroactive Identifiable {
    public var id: String { name }
}
