import SwiftUI
import EchoSense

extension WorkspaceToolbarItems {

    // MARK: - Project Menu

    internal var projectMenu: some View {
        Menu {
            if projectStore.projects.isEmpty {
                Text("No Projects Available").foregroundStyle(.secondary)
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
                navigationStore.showManageProjectsSheet = true
            }
        } label: {
            toolbarButtonLabel(
                icon: projectIcon,
                title: projectStore.selectedProject?.name ?? "Project"
            )
        }
    }
}
