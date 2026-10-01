import SwiftUI

/// What "Customize Dock" opens: which sections the dock shows and in what order, for every
/// server of this database type or for this server alone, and the dock's own icon style. In Echo
/// the per-type part would live in Settings › Sidebar and the per-server part in this sheet.
struct LabSCCustomizeSheet: View {
    let server: LabSCServer
    let state: LabSCState
    @Binding var dockIcons: LabSCIconStyle
    @Binding var treeIcons: LabSCIconStyle

    enum Scope: String, CaseIterable, Identifiable {
        case type = "Every server of this type"
        case server = "This server only"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .type
    @State private var order: [String] = []
    @State private var shown: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            Form {
                Section {
                    Picker("Applies to", selection: $scope) {
                        ForEach(Scope.allCases) { Text(scopeTitle($0)).tag($0) }
                    }
                } header: {
                    Text("Dock for \(server.name)")
                } footer: {
                    Text("Sections left out stay one click away under More.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Section("Sections") {
                    List {
                        ForEach(order, id: \.self) { id in
                            if let section = server.section(id) {
                                Toggle(isOn: binding(for: id)) {
                                    Label(section.title, systemImage: section.symbol)
                                }
                            }
                        }
                        .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .frame(minHeight: SpacingTokens.xxxl * 3)
                }
                Section("Icons") {
                    Picker("Dock", selection: $dockIcons) {
                        ForEach(LabSCIconStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Tree", selection: $treeIcons) {
                        ForEach(LabSCIconStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Use \(server.engine.rawValue) Defaults") { load(LabSCDefaults.dock(for: server.engine)) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Done") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(shown.isEmpty)
            }
            .padding(SpacingTokens.md)
        }
        .frame(width: SpacingTokens.xxxl * 7, height: SpacingTokens.xxxl * 8)
        .onAppear { load(state.dock(for: server)) }
    }

    private func scopeTitle(_ scope: Scope) -> String {
        switch scope {
        case .type: "Every \(server.engine.rawValue) server"
        case .server: "\(server.name) only"
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { shown.contains(id) },
            set: { isOn in if isOn { shown.insert(id) } else { shown.remove(id) } }
        )
    }

    /// Shown sections first, in dock order, then the rest in the blueprint's order.
    private func load(_ dock: [String]) {
        shown = Set(dock)
        order = dock + server.sections.map(\.id).filter { !dock.contains($0) }
    }

    private func save() {
        state.setDock(order.filter(shown.contains), for: server, onlyThisServer: scope == .server)
        dismiss()
    }
}
