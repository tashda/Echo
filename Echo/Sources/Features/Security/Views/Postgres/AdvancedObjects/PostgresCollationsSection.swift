import SwiftUI
import PostgresKit

struct PostgresCollationsSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.collations, selection: $selection) {
            TableColumn("Name") { col in
                Text(col.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Schema") { col in
                Text(col.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Provider") { col in
                Text(col.provider ?? "\u{2014}")
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(col.provider != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Locale") { col in
                Text(col.locale ?? col.lcCollate ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle((col.locale ?? col.lcCollate) != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(min: 80, ideal: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Collation", objectName: $pendingDropName, cascade: true) { name in
            let col = viewModel.collations.first { $0.name == name }
            Task { await viewModel.dropCollation(name, schema: col?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                let col = viewModel.collations.first { $0.name == edit.objectName }
                let schema = col?.schema ?? "public"
                switch edit.action {
                case .rename: await viewModel.renameCollation(edit.objectName, schema: schema, newName: newValue)
                case .changeOwner: await viewModel.changeCollationOwner(edit.objectName, schema: schema, newOwner: newValue)
                case .changeSchema: await viewModel.setCollationSchema(edit.objectName, schema: schema, newSchema: newValue)
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
                Label("New Collation", systemImage: "abc")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let col = viewModel.collations.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(col.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "COLLATION", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let col = viewModel.collations.first { $0.name == name }
                Button("Rename\u{2026}") {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                }
                Button("Change Owner\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                }
                Button("Change Schema\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: name, initialValue: col?.schema ?? "public")
                }
                Button("Refresh Version") {
                    let schema = col?.schema ?? "public"
                    Task { await viewModel.refreshCollationVersion(name, schema: schema) }
                }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Collation", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let col = viewModel.collations.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(col.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "COLLATION", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Collations", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresCollationInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
