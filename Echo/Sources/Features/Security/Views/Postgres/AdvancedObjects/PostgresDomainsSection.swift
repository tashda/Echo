import SwiftUI
import PostgresKit

struct PostgresDomainsSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.domains, selection: $selection) {
            TableColumn("Name") { domain in
                Text(domain.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Schema") { domain in
                Text(domain.schema).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Data Type") { domain in
                Text(domain.dataType).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Default") { domain in
                Text(domain.defaultValue ?? "\u{2014}")
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(domain.defaultValue != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("NOT NULL") { domain in
                Text(domain.isNotNull ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(domain.isNotNull ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
            }
            .width(60)

            TableColumn("Constraints") { domain in
                let count = domain.constraints.count
                Text(count > 0 ? "\(count)" : "\u{2014}")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(count > 0 ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }
            .width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Domain", objectName: $pendingDropName, cascade: true) { name in
            let domain = viewModel.domains.first { $0.name == name }
            Task { await viewModel.dropDomain(name, schema: domain?.schema ?? "public") }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                let domain = viewModel.domains.first { $0.name == edit.objectName }
                let schema = domain?.schema ?? "public"
                switch edit.action {
                case .rename: await viewModel.renameDomain(edit.objectName, schema: schema, newName: newValue)
                case .changeOwner: await viewModel.changeDomainOwner(edit.objectName, schema: schema, newOwner: newValue)
                case .changeSchema: await viewModel.setDomainSchema(edit.objectName, schema: schema, newSchema: newValue)
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
                Label("New Domain", systemImage: "d.square")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.compactMap { name -> String? in
                        guard let domain = viewModel.domains.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(domain.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "DOMAIN", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let domain = viewModel.domains.first { $0.name == name }
                Button {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Button {
                    pendingEdit = PendingEdit(action: .changeSchema, objectName: name, initialValue: domain?.schema ?? "public")
                } label: { Label("Change Schema", systemImage: "rectangle.stack") }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Domain", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.compactMap { name -> String? in
                        guard let domain = viewModel.domains.first(where: { $0.name == name }) else { return nil }
                        let qualifiedName = "\(ScriptingActions.pgQuote(domain.schema)).\(ScriptingActions.pgQuote(name))"
                        return ScriptingActions.scriptDrop(objectType: "DOMAIN", qualifiedName: qualifiedName)
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Domains", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresDomainInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
