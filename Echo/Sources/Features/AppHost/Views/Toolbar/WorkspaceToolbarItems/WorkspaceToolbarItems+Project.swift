import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Project Context Menu

    @ViewBuilder
    internal var projectContextMenu: some View {
        Menu {
            Section("Projects") {
                if projectStore.projects.isEmpty {
                    Text("No Projects Available")
                } else {
                    ForEach(projectStore.projects) { project in
                        let isSelected = project.id == projectStore.selectedProject?.id
                        Toggle(isOn: Binding(get: { isSelected }, set: { _ in
                            environmentState.requestProjectSwitch(to: project)
                        })) {
                            Label(project.name, systemImage: project.iconName ?? "folder.fill")
                        }
                    }
                }
            }

            Divider()

            Button {
                let projectID = projectStore.selectedProject?.id
                ManageConnectionsWindowController.shared.present(initialSection: .projects, selectedProjectID: projectID)
            } label: {
                Label("Manage Projects", systemImage: "folder.badge.gearshape")
            }
        } label: {
            let project = projectStore.selectedProject ?? Project.defaultProject
            Label(project.name, systemImage: project.iconName ?? "folder.fill")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
    }
}
