import SwiftUI
import PostgresKit

struct PostgresRulesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.rules, selection: $selection) {
            TableColumn("Name") { rule in
                Text(rule.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Table") { rule in
                Text(rule.table).font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Schema") { rule in
                Text(rule.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Event") { rule in
                Text(rule.event).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(60)

            TableColumn("DO INSTEAD") { rule in
                Text(rule.doInstead ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(rule.doInstead ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
            }
            .width(80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Rule", objectName: $pendingDropName, cascade: true) { name in
            let rule = viewModel.rules.first { $0.name == name }
            Task { await viewModel.dropRule(name, table: rule?.table ?? "", schema: rule?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                if case .rename = edit.action {
                    let rule = viewModel.rules.first { $0.name == edit.objectName }
                    await viewModel.renameRule(
                        edit.objectName,
                        tableName: rule?.table ?? "",
                        schema: rule?.schema ?? "public",
                        newName: newValue
                    )
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
                Label("New Rule", systemImage: "list.bullet.rectangle")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            if selection.count == 1, let name = selection.first,
               let rule = viewModel.rules.first(where: { $0.name == name }) {
                Button {
                    openScript(rule.definition)
                } label: { Label("Show Definition", systemImage: "eye") }
                Divider()
            }

            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let rule = viewModel.rules.first(where: { $0.name == name }) else { return nil }
                        let qualifiedTable = "\(ScriptingActions.pgQuote(rule.schema)).\(ScriptingActions.pgQuote(rule.table))"
                        return "DROP RULE IF EXISTS \(ScriptingActions.pgQuote(name)) ON \(qualifiedTable);"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                Button("Rename\u{2026}") {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Rule", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let rule = viewModel.rules.first(where: { $0.name == name }) else { return nil }
                        let qualifiedTable = "\(ScriptingActions.pgQuote(rule.schema)).\(ScriptingActions.pgQuote(rule.table))"
                        return "DROP RULE IF EXISTS \(ScriptingActions.pgQuote(name)) ON \(qualifiedTable);"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Rules", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresRuleInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(table).\(name)" }
}
