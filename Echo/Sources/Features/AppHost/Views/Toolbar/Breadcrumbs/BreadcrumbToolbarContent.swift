import SwiftUI

#if os(macOS)
import AppKit

/// Native NSPopUpButton toolbar menus for Project, Connections, and Databases.
///
/// Menus flow from the toolbar with native Liquid Glass on macOS 26.
/// Uses NSViewRepresentable wrappers so SwiftUI manages the toolbar
/// while the menus are pure AppKit.

// MARK: - Project Menu Button

struct ProjectMenuButton: NSViewRepresentable {
    let projectStore: ProjectStore
    let navigationStore: NavigationStore
    let environmentState: EnvironmentState

    func makeCoordinator() -> ProjectMenuDelegate {
        ProjectMenuDelegate(projectStore: projectStore, navigationStore: navigationStore, environmentState: environmentState)
    }

    func makeNSView(context: Context) -> ProjectButtonContentView {
        let view = ProjectButtonContentView(
            projectName: projectStore.selectedProject?.name ?? "Project",
            subtitle: "Local",
            target: context.coordinator,
            action: #selector(ProjectMenuDelegate.showMenu(_:))
        )
        return view
    }

    func updateNSView(_ view: ProjectButtonContentView, context: Context) {
        context.coordinator.projectStore = projectStore
        context.coordinator.navigationStore = navigationStore
        context.coordinator.environmentState = environmentState
        view.update(
            projectName: projectStore.selectedProject?.name ?? "Project",
            subtitle: "Local"
        )
        // Remove Liquid Glass bezel from the hosting toolbar item
        view.configureToolbarItemPlain()
    }
}

final class ProjectButtonContentView: NSView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    init(projectName: String, subtitle: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        setupViews()
        update(projectName: projectName, subtitle: subtitle)

        let click = NSClickGestureRecognizer(target: target, action: action)
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.isEditable = false
        subtitleLabel.isBordered = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(nameLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: topAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: -1),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(projectName: String, subtitle: String) {
        nameLabel.stringValue = projectName
        subtitleLabel.stringValue = subtitle
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let width = max(nameLabel.intrinsicContentSize.width, subtitleLabel.intrinsicContentSize.width)
        let height = nameLabel.intrinsicContentSize.height + subtitleLabel.intrinsicContentSize.height - 1
        return NSSize(width: width, height: height)
    }

    override func mouseDown(with event: NSEvent) {
        // Forward to gesture recognizer
        super.mouseDown(with: event)
    }

    /// Find the hosting NSToolbarItem and set its style to `.plain`
    /// to remove the Liquid Glass bezel.
    func configureToolbarItemPlain() {
        guard !didConfigureToolbarItem else { return }
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            if item.itemIdentifier.rawValue.contains("project") {
                item.isBordered = false
                if #available(macOS 26.0, *) {
                    item.style = .plain
                }
                didConfigureToolbarItem = true
                return
            }
        }
    }

    private var didConfigureToolbarItem = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Defer to allow toolbar item to fully install
        Task { @MainActor [weak self] in
            self?.configureToolbarItemPlain()
        }
    }
}

@MainActor
final class ProjectMenuDelegate: NSObject {
    var projectStore: ProjectStore
    var navigationStore: NavigationStore
    var environmentState: EnvironmentState

    init(projectStore: ProjectStore, navigationStore: NavigationStore, environmentState: EnvironmentState) {
        self.projectStore = projectStore
        self.navigationStore = navigationStore
        self.environmentState = environmentState
        super.init()
    }

    @objc func showMenu(_ sender: Any?) {
        let sourceView: NSView?
        if let gesture = sender as? NSGestureRecognizer {
            sourceView = gesture.view
        } else if let view = sender as? NSView {
            sourceView = view
        } else {
            sourceView = nil
        }

        let menu = NSMenu()

        let projects = projectStore.projects
        if projects.isEmpty {
            let empty = NSMenuItem(title: "No Projects Available", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for project in projects {
                let item = NSMenuItem(title: project.name, action: #selector(selectProject(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = project
                item.state = (project.id == projectStore.selectedProject?.id) ? .on : .off
                item.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let manage = NSMenuItem(title: "Manage Projects", action: #selector(manageProjects(_:)), keyEquivalent: "")
        manage.target = self
        manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(manage)

        if let sourceView {
            let point = NSPoint(x: 0, y: sourceView.bounds.maxY + 4)
            menu.popUp(positioning: nil, at: point, in: sourceView)
        }
    }

    @objc private func selectProject(_ sender: NSMenuItem) {
        guard let project = sender.representedObject as? Project else { return }
        environmentState.requestProjectSwitch(to: project)
    }

    @objc private func manageProjects(_ sender: NSMenuItem) {
        ManageConnectionsWindowController.shared.present(initialSection: .projects)
    }
}

#endif
