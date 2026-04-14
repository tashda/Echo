import SwiftUI
import PostgresKit

struct PostgresFDWSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selectedFDW: Set<String> = []
    @State private var selectedServer: Set<String> = []
    @State private var pendingDropFDW: String?
    @State private var pendingDropServer: String?
    @State private var pendingFDWEdit: PendingEdit?
    @State private var pendingServerEdit: PendingEdit?

    var body: some View {
        VSplitView {
            fdwTable
            serverTable
        }
        .dropConfirmationAlert(objectType: "Foreign Data Wrapper", objectName: $pendingDropFDW, cascade: true) { name in
            Task { await viewModel.dropFDW(name) }
        }
        .dropConfirmationAlert(objectType: "Foreign Server", objectName: $pendingDropServer, cascade: true) { name in
            Task { await viewModel.dropForeignServer(name) }
        }
        .sheet(item: $pendingFDWEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameFDW(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeFDWOwner(edit.objectName, newOwner: newValue)
                case .changeSchema: break
                }
            } onCancel: {
                pendingFDWEdit = nil
            }
        }
        .sheet(item: $pendingServerEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameForeignServer(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeForeignServerOwner(edit.objectName, newOwner: newValue)
                case .changeSchema: break
                }
            } onCancel: {
                pendingServerEdit = nil
            }
        }
    }

    private var fdwTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Foreign Data Wrappers")
                .font(TypographyTokens.headline)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)

            Table(viewModel.fdws, selection: $selectedFDW) {
                TableColumn("Name") { fdw in
                    Text(fdw.name).font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Handler") { fdw in
                    Text(fdw.handler ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(fdw.handler != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                }
                .width(min: 80, ideal: 140)

                TableColumn("Validator") { fdw in
                    Text(fdw.validator ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(fdw.validator != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                }
                .width(min: 80, ideal: 140)

                TableColumn("Owner") { fdw in
                    Text(fdw.owner).font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 60, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: String.self) { selection in
                fdwContextMenu(selection: selection)
            } primaryAction: { _ in }
        }
        .frame(minHeight: 120)
    }

    private var serverTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Foreign Servers")
                .font(TypographyTokens.headline)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)

            Table(viewModel.foreignServers, selection: $selectedServer) {
                TableColumn("Name") { srv in
                    Text(srv.name).font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Type") { srv in
                    Text(srv.type ?? "\u{2014}")
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(srv.type != nil ? ColorTokens.Text.secondary : ColorTokens.Text.tertiary)
                }
                .width(min: 60, ideal: 80)

                TableColumn("Version") { srv in
                    Text(srv.version ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(srv.version != nil ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                }
                .width(min: 50, ideal: 70)

                TableColumn("FDW") { srv in
                    Text(srv.fdwName).font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Owner") { srv in
                    Text(srv.owner).font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 60, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: String.self) { selection in
                serverContextMenu(selection: selection)
            } primaryAction: { _ in }
        }
        .frame(minHeight: 120)
    }

    @ViewBuilder
    private func fdwContextMenu(selection: Set<String>) -> some View {
        if selection.isEmpty {
            Button { onCreate?() } label: {
                Label("New Foreign Data Wrapper", systemImage: "network")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "FOREIGN DATA WRAPPER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                Button {
                    pendingFDWEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingFDWEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Divider()
                Button(role: .destructive) { pendingDropFDW = name } label: {
                    Label("Drop FDW", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "FOREIGN DATA WRAPPER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) FDWs", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func serverContextMenu(selection: Set<String>) -> some View {
        if selection.isEmpty {
            Button { onCreate?() } label: {
                Label("New Foreign Server", systemImage: "network")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "SERVER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                Button {
                    pendingServerEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
                Button {
                    pendingServerEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                } label: { Label("Change Owner", systemImage: "person") }
                Divider()
                Button(role: .destructive) { pendingDropServer = name } label: {
                    Label("Drop Server", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "SERVER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Servers", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresFDWInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension PostgresForeignServerInfo: @retroactive Identifiable {
    public var id: String { name }
}
