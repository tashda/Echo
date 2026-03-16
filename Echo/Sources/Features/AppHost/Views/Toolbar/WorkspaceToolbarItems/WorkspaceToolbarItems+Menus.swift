import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Project Menu

    internal var projectMenu: some View {
        let selectedProject = projectStore.selectedProject ?? Project.defaultProject
        return Menu {
            if projectStore.projects.isEmpty {
                Text("No Projects Available").foregroundStyle(ColorTokens.Text.secondary)
            } else {
                ForEach(projectStore.projects) { project in
                    let isSelected = project.id == selectedProject.id
                    Toggle(isOn: Binding(get: { isSelected }, set: { _ in
                        environmentState.requestProjectSwitch(to: project)
                    })) {
                        Label(project.name, systemImage: project.iconName ?? "folder.fill")
                    }
                }
            }

            Divider()

            Button("Manage Projects") {
                ManageConnectionsWindowController.shared.present(initialSection: .projects)
            }
        } label: {
            toolbarButtonLabel(
                icon: selectedProject.toolbarIcon,
                title: selectedProject.name
            )
        }
    }
}
