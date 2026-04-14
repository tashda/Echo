import SwiftUI
import PostgresKit

struct PostgresLanguagesSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.languages, selection: $selection) {
            TableColumn("Name") { lang in
                Text(lang.name).font(TypographyTokens.Table.name)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Owner") { lang in
                Text(lang.owner).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Procedural") { lang in
                Text(lang.isPL ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(lang.isPL ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
            }
            .width(70)

            TableColumn("Trusted") { lang in
                Text(lang.isTrusted ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(lang.isTrusted ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Language", objectName: $pendingDropName, cascade: true) { name in
            Task { await viewModel.dropLanguage(name) }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameLanguage(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeLanguageOwner(edit.objectName, newOwner: newValue)
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
                Label("New Language", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.map { name in
                        "DROP LANGUAGE IF EXISTS \(ScriptingActions.pgQuote(name)) CASCADE;"
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
                    Label("Drop Language", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.map { name in
                        "DROP LANGUAGE IF EXISTS \(ScriptingActions.pgQuote(name)) CASCADE;"
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Languages", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresLanguageInfo: @retroactive Identifiable {
    public var id: String { name }
}
