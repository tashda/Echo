import SwiftUI
import PostgresKit

struct PostgresEventTriggersSection: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(EnvironmentState.self) private var environmentState
    var onCreate: (() -> Void)?

    @State private var selection: Set<String> = []
    @State private var pendingDropName: String?
    @State private var pendingEdit: PendingEdit?

    var body: some View {
        Table(viewModel.eventTriggers, selection: $selection) {
            TableColumn("Name") { trigger in
                Text(trigger.name).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Event") { trigger in
                Text(trigger.event).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Function") { trigger in
                Text(trigger.function).font(TypographyTokens.Table.secondaryName)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Enabled") { trigger in
                let isEnabled = trigger.enabled == "O"
                Text(isEnabled ? "Yes" : "No")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(isEnabled ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .width(60)

            TableColumn("Owner") { trigger in
                Text(trigger.owner).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { selection in
            contextMenuItems(selection: selection)
        } primaryAction: { _ in }
        .dropConfirmationAlert(objectType: "Event Trigger", objectName: $pendingDropName, cascade: true) { name in
            Task { await viewModel.dropEventTrigger(name) }
        }
        .sheet(item: $pendingEdit) { edit in
            SingleFieldEditSheet(
                title: edit.title,
                fieldLabel: edit.fieldLabel,
                initialValue: edit.initialValue
            ) { newValue in
                switch edit.action {
                case .rename: await viewModel.renameEventTrigger(edit.objectName, newName: newValue)
                case .changeOwner: await viewModel.changeEventTriggerOwner(edit.objectName, newOwner: newValue)
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
                Label("New Event Trigger", systemImage: "bolt")
            }
            Divider()
            Button { Task { await viewModel.loadCurrentSection() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } else {
            Menu("Script as", systemImage: "scroll") {
                Button {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "EVENT TRIGGER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            if selection.count == 1, let name = selection.first {
                let trigger = viewModel.eventTriggers.first { $0.name == name }
                let isEnabled = trigger?.enabled == "O"
                Button("Rename\u{2026}") {
                    pendingEdit = PendingEdit(action: .rename, objectName: name, initialValue: name)
                }
                Button("Change Owner\u{2026}") {
                    pendingEdit = PendingEdit(action: .changeOwner, objectName: name, initialValue: "")
                }
                Divider()
                if isEnabled {
                    Button("Disable") {
                        Task { await viewModel.disableEventTrigger(name) }
                    }
                } else {
                    Button("Enable") {
                        Task { await viewModel.enableEventTrigger(name) }
                    }
                }
                Divider()
                Button(role: .destructive) { pendingDropName = name } label: {
                    Label("Drop Event Trigger", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    let scripts = selection.map { name in
                        ScriptingActions.scriptDrop(objectType: "EVENT TRIGGER", qualifiedName: ScriptingActions.pgQuote(name))
                    }
                    openScript(scripts.joined(separator: "\n"))
                } label: {
                    Label("Drop \(selection.count) Event Triggers", systemImage: "trash")
                }
            }
        }
    }

    private func openScript(_ sql: String) {
        environmentState.openScriptTab(sql: sql, connectionID: viewModel.connectionID)
    }
}

extension PostgresEventTriggerInfo: @retroactive Identifiable {
    public var id: String { name }
}
