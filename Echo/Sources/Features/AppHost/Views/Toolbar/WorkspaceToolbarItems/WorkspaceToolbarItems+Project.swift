import SwiftUI
import EchoSense

/// Standalone view that properly observes `@Observable` state changes.
/// See `RecentConnectionsMenuButton` for rationale.
struct ProjectContextMenuButton: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AuthState.self) private var authState
    @Environment(\.openWindow) private var openWindow

    @State private var avatarImage: NSImage?

    private var showAccount: Bool {
        authState.isSignedIn
            && projectStore.globalSettings.toolbarProjectButtonStyle == .account
    }

    var body: some View {
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

            if authState.isSignedIn {
                Button {
                    openWindow(id: SettingsWindowScene.sceneID)
                    NotificationCenter.default.post(name: .openSettingsSection, object: "general")
                } label: {
                    Label("Manage Account", systemImage: "person.crop.circle")
                }
            } else {
                Button {
                    openWindow(id: SettingsWindowScene.sceneID)
                    NotificationCenter.default.post(name: .openSettingsSection, object: "general")
                } label: {
                    Label("Sign In to Echo", systemImage: "person.crop.circle.badge.plus")
                }
            }
        } label: {
            toolbarLabel
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .task(id: authState.currentUser?.avatarURL) {
            await loadAvatar()
        }
    }

    // MARK: - Toolbar Label

    private var toolbarLabel: some View {
        let project = projectStore.selectedProject ?? Project.defaultProject
        return Label {
            Text(project.name)
        } icon: {
            if showAccount, let avatarImage {
                Image(nsImage: avatarImage)
            } else if showAccount {
                initialsIcon
            } else {
                Image(systemName: project.iconName ?? "folder.fill")
            }
        }
    }

    // MARK: - Initials Icon

    private var initialsIcon: some View {
        let initials = avatarInitials
        let img = renderInitialsAvatar(initials: initials, size: 28)
        return Image(nsImage: img)
    }

    private var avatarInitials: String {
        let name = authState.currentUser?.displayName
            ?? authState.currentUser?.email
            ?? "U"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func renderInitialsAvatar(initials: String, size: CGFloat) -> NSImage {
        let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            // Background circle
            let bgColor = NSColor.systemGray.withAlphaComponent(0.3)
            bgColor.setFill()
            NSBezierPath(ovalIn: rect).fill()

            // Text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size * 0.38, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let text = NSAttributedString(string: initials, attributes: attributes)
            let textSize = text.size()
            let textOrigin = NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            text.draw(at: textOrigin)
            return true
        }
        result.isTemplate = false
        return result
    }

    // MARK: - Avatar Loading

    private func loadAvatar() async {
        guard showAccount, let url = authState.currentUser?.avatarURL else {
            avatarImage = nil
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let source = NSImage(data: data) else { return }
            avatarImage = circularAvatar(from: source, size: 28)
        } catch {
            avatarImage = nil
        }
    }

    private func circularAvatar(from source: NSImage, size: CGFloat) -> NSImage {
        let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect)
            path.addClip()
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        result.isTemplate = false
        return result
    }
}
