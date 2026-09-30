import SwiftUI

/// What Customize Dock edits: one server's dock sections, captured when the menu was chosen.
struct ExplorerDockCustomization: Identifiable {
    var id: UUID { connectionID }
    let connectionID: UUID
    let serverName: String
    let typeName: String
    /// Every section the server has, the dock's first, then the rest.
    let items: [ExplorerDockItem]
    let shownKeys: [String]
    /// The blueprint's default dock for the type.
    let defaultKeys: [String]
}

/// Customize Dock (round 16): which sections the capsule shows and in what order, for every
/// server of the type or this server only, and the dock's icon style apart from the tree's.
struct ExplorerDockCustomizationSheet: View {
    let customization: ExplorerDockCustomization
    let onSave: ([String], ExplorerDockScope) -> Void
    let onCancel: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @State private var scope: ExplorerDockScope = .type
    @State private var order: [String] = []
    @State private var shown: Set<String> = []

    var body: some View {
        SheetLayout(
            title: "Customize Dock",
            icon: "dock.rectangle",
            subtitle: customization.serverName,
            primaryAction: "Done",
            canSubmit: !shown.isEmpty,
            onSubmit: { onSave(order.filter(shown.contains), scope) },
            onCancel: onCancel
        ) {
            Form {
                Section {
                    Picker("Applies to", selection: $scope) {
                        Text("Every \(customization.typeName) server").tag(ExplorerDockScope.type)
                        Text("\(customization.serverName) only").tag(ExplorerDockScope.server)
                    }
                }
                Section {
                    ForEach(order, id: \.self) { key in
                        if let item = customization.items.first(where: { $0.key == key }) {
                            Toggle(isOn: binding(for: key)) {
                                Label(item.title, systemImage: item.symbol)
                            }
                        }
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Sections")
                } footer: {
                    Text("Drag to reorder. Sections left out stay under More.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Section("Icons") {
                    Picker("Dock", selection: dockStyle) {
                        ForEach(SidebarDockIconStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Tree", selection: treeStyle) {
                        ForEach(SidebarIconColorMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Button("Use Default Sections") { load(customization.defaultKeys) }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear { load(customization.shownKeys) }
    }

    private func binding(for key: String) -> Binding<Bool> {
        Binding(
            get: { shown.contains(key) },
            set: { isOn in if isOn { shown.insert(key) } else { shown.remove(key) } }
        )
    }

    /// Shown sections first, in dock order, then the rest in the blueprint's order.
    private func load(_ keys: [String]) {
        shown = Set(keys)
        order = keys + customization.items.map(\.key).filter { !keys.contains($0) }
    }

    private var dockStyle: Binding<SidebarDockIconStyle> {
        Binding(
            get: { projectStore.globalSettings.sidebarDockIconStyle },
            set: { value in
                var settings = projectStore.globalSettings
                settings.sidebarDockIconStyle = value
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var treeStyle: Binding<SidebarIconColorMode> {
        Binding(
            get: { projectStore.globalSettings.sidebarIconColorMode },
            set: { value in
                var settings = projectStore.globalSettings
                settings.sidebarIconColorMode = value
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }
}
