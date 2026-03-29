import SwiftUI
import PostgresKit

struct PostgresFTSConfigSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.ftsConfigs, selection: $selection) {
            TableColumn("Name") { cfg in
                Text(cfg.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Schema") { cfg in
                Text(cfg.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Parser") { cfg in
                Text(cfg.parser).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Text Search Configuration", objectName: $pendingDropName, cascade: true) { name in
            let cfg = viewModel.ftsConfigs.first { $0.name == name }
            Task { await viewModel.dropFTSConfig(name, schema: cfg?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                let cfg = viewModel.ftsConfigs.first { $0.name == edit.objectName }
                let schema = cfg?.schema ?? "public"
                switch edit.action {
                case .rename: await viewModel.renameFTSConfig(edit.objectName, schema: schema, newName: newValue)
                case .changeOwner: await viewModel.changeFTSConfigOwner(edit.objectName, schema: schema, newOwner: newValue)
                case .changeSchema: await viewModel.setFTSConfigSchema(edit.objectName, schema: schema, newSchema: newValue)
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
                Label("New FTS Configuration", systemImage: "magnifyingglass")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let cfg = viewModel.ftsConfigs.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(cfg.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TEXT SEARCH CONFIGURATION", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let cfg = viewModel.ftsConfigs.first { $0.name == name }
                Button("Rename\u{2026}") {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                }
                Button("Change Owner\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                }
                Button("Change Schema\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: name, initialValue: cfg?.schema ?? "public")
                }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Configuration", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let cfg = viewModel.ftsConfigs.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(cfg.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TEXT SEARCH CONFIGURATION", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Configurations", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresFTSConfigInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
