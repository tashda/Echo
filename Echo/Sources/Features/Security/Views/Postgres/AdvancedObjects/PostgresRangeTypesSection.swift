import SwiftUI
import PostgresKit

struct PostgresRangeTypesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.rangeTypes, selection: $selection) {
            TableColumn("Name") { range in
                Text(range.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Schema") { range in
                Text(range.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Subtype") { range in
                Text(range.subtype).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Collation") { range in
                Text(range.collation ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(range.collation != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Op Class") { range in
                Text(range.subtypeOpClass ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(range.subtypeOpClass != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(min: 60, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Range Type", objectName: $pendingDropName, cascade: true) { name in
            let range = viewModel.rangeTypes.first { $0.name == name }
            Task { await viewModel.dropRangeType(name, schema: range?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                let range = viewModel.rangeTypes.first { $0.name == edit.objectName }
                let schema = range?.schema ?? "public"
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
                Label("New Range Type", systemImage: "arrow.left.and.right")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let range = viewModel.rangeTypes.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(range.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TYPE", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let range = viewModel.rangeTypes.first { $0.name == name }
                Button("Rename\u{2026}") {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                }
                Button("Change Owner\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                }
                Button("Change Schema\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: name, initialValue: range?.schema ?? "public")
                }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Range Type", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let range = viewModel.rangeTypes.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(range.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "TYPE", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Range Types", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresRangeTypeInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
