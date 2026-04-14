import SwiftUI
import PostgresKit

struct PostgresAggregatesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.aggregates, selection: $selection) {
            TableColumn("Name") { agg in
                Text(agg.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Schema") { agg in
                Text(agg.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Input Type") { agg in
                Text(agg.inputType).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("State Function") { agg in
                Text(agg.stateFunction).font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)

            TableColumn("State Type") { agg in
                Text(agg.stateType).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Initial Value") { agg in
                if let val = agg.initialValue {
                    Text(val).font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}").foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Aggregate", objectName: $pendingDropName, cascade: true) { name in
            Task { await viewModel.dropAggregate(name) }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameAggregate(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeAggregateOwner(edit.objectName, newOwner: newValue)
                case .changeSchema: await viewModel.setAggregateSchema(edit.objectName, newSchema: newValue)
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
                Label("New Aggregate", systemImage: "function")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { id -> String? in
                        guard let agg = viewModel.aggregates.first(where: { $0.id == id }) else { return nil }
                        let qualifiedName = ScriptingActions.pgQualifiedName(schema: agg.schema, name: agg.name)
                        return "DROP AGGREGATE IF EXISTS \(qualifiedName)(\(agg.inputType)) CASCADE;"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let id = selection.first {
                let agg = viewModel.aggregates.first { $0.id == id }
                Button {
                    pendingEdit = PendingEdit(action: .rename, objectName: id, initialValue: agg?.name ?? "")
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: id, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Button {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: id, initialValue: agg?.schema ?? "public")
                } label: { Label("Change Schema", systemImage: "rectangle.stack") }
                Divider()
                Button(role: .destructive) { pendingDropName = id } label: {
                    Label("Drop Aggregate", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { id -> String? in
                        guard let agg = viewModel.aggregates.first(where: { $0.id == id }) else { return nil }
                        let qualifiedName = ScriptingActions.pgQualifiedName(schema: agg.schema, name: agg.name)
                        return "DROP AGGREGATE IF EXISTS \(qualifiedName)(\(agg.inputType)) CASCADE;"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Aggregates", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresAggregateInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)(\(inputType))" }
}
