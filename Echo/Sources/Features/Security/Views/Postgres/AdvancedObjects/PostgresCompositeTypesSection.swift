import SwiftUI
import PostgresKit

struct PostgresCompositeTypesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.compositeTypes, selection: $selection) {
            TableColumn("Name") { type in
                Text(type.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Schema") { type in
                Text(type.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Attributes") { type in
                Text("\(type.attributes.count)")
                    .font(TypographyTokens.Table.numeric)
            }
            .width(70)

            TableColumn("Attribute Details") { type in
                let summary = type.attributes.prefix(3).map { "\($0.name): \($0.dataType)" }.joined(separator: ", ")
                let suffix = type.attributes.count > 3 ? ", \u{2026}" : ""
                Text(summary.isEmpty ? "\u{2014}" : "\(summary)\(suffix)")
                    .font(TypographyTokens.Table.sql)
                    .foregroundStyle(summary.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
            .width(min: 120, ideal: 300)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Composite Type", objectName: $pendingDropName, cascade: true) { name in
            let type = viewModel.compositeTypes.first { $0.name == name }
            Task { await viewModel.dropCompositeType(name, schema: type?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                let type = viewModel.compositeTypes.first { $0.name == edit.objectName }
                let schema = type?.schema ?? "public"
                switch edit.action {
                case .rename: await viewModel.renameType(edit.objectName, schema: schema, newName: newValue)
                case .changeOwner: await viewModel.changeTypeOwner(edit.objectName, schema: schema, newOwner: newValue)
                case .changeSchema: await viewModel.setTypeSchema(edit.objectName, schema: schema, newSchema: newValue)
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
                Label("New Composite Type", systemImage: "rectangle.3.group")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let type = viewModel.compositeTypes.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(type.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TYPE", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let type = viewModel.compositeTypes.first { $0.name == name }
                Button {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Button {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: name, initialValue: type?.schema ?? "public")
                } label: { Label("Change Schema", systemImage: "rectangle.stack") }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Type", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let type = viewModel.compositeTypes.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(type.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TYPE", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Types", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresCompositeTypeInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
