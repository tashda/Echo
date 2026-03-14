import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Project Menu

    internal var projectMenu: some View {
        Menu {
            if projectStore.projects.isEmpty {
                Text("No Projects Available").foregroundStyle(ColorTokens.Text.secondary)
            } else {
                ForEach(projectStore.projects) { project in
                    Button {
                        projectStore.selectProject(project)
                        navigationStore.selectProject(project)
                    } label: {
                        menuRow(
                            icon: projectIcon,
                            title: project.name,
                            isSelected: project.id == projectStore.selectedProject?.id
                        )
                    }
                }
            }

            Divider()

            Button("Manage Projects…") {
                ManageConnectionsWindowController.shared.present(initialSection: .projects)
            }
        } label: {
            toolbarButtonLabel(
                icon: projectIcon,
                title: projectStore.selectedProject?.name ?? "Project"
            )
        }
    }
}
