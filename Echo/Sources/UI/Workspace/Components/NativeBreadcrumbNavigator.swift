import SwiftUI

#if os(macOS)
import AppKit

/// Minimal AppKit-based toolbar navigator, matching Xcode's breadcrumb appearance.
/// - Items: Connections, Databases
/// - Status: trailing text label (e.g., Ready/Running)
struct NativeBreadcrumbNavigator: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NativeBreadcrumbNavigatorRepresentable(
            statusText: statusText
        )
        .frame(height: WorkspaceChromeMetrics.toolbarTabBarHeight)
    }

    private var statusText: String {
        // Simple status mapping; extend as needed.
        "Ready"
    }
}

// MARK: - Representable

private struct NativeBreadcrumbNavigatorRepresentable: NSViewRepresentable {
    let statusText: String

    func makeNSView(context: Context) -> NativeBreadcrumbToolbarView {
        let view = NativeBreadcrumbToolbarView()
        view.statusText = statusText
        return view
    }

    func updateNSView(_ nsView: NativeBreadcrumbToolbarView, context: Context) {
        nsView.statusText = statusText
    }
}

// MARK: - Toolbar View

private final class NativeBreadcrumbToolbarView: NSView {
    var statusText: String = "Ready" {
        didSet { applyConfiguration() }
    }

    private let effectView = NSVisualEffectView()
    private let contentStack = NSStackView()
    private let pathControl = NSPathControl()
    private let statusLabel = NSTextField(labelWithString: "")
    private var widthConstraint: NSLayoutConstraint?
    private var activePopover: NSPopover?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        configureLayout()
        applyConfiguration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureLayout() {
        effectView.material = .headerView
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.wantsLayer = true
        addSubview(effectView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 4),
            contentStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -4)
        ])

        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.pathStyle = .standard
        pathControl.focusRingType = .none
        pathControl.target = self
        pathControl.action = #selector(handleSelection(_:))
        pathControl.backgroundColor = .clear
        pathControl.controlSize = .regular
        pathControl.setContentHuggingPriority(.defaultLow, for: .horizontal)

        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .labelColor

        contentStack.addArrangedSubview(pathControl)
        contentStack.addArrangedSubview(statusLabel)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)

        widthConstraint = widthAnchor.constraint(equalToConstant: 500)
        widthConstraint?.isActive = true
    }

    private func applyConfiguration() {
        // Capsule shaping comes from the effect view + layer corner radius.
        let height = WorkspaceChromeMetrics.toolbarTabBarHeight
        effectView.layer?.cornerRadius = height / 2
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0
        layer?.shadowOpacity = 0

        // Path items: Connections, Databases
        let connections = NSPathControlItem()
        connections.title = "Connections"
        connections.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)

        let databases = NSPathControlItem()
        databases.title = "Databases"
        databases.image = NSImage(systemSymbolName: "cylinder", accessibilityDescription: nil)

        pathControl.pathItems = [connections, databases]
        statusLabel.stringValue = statusText
        applyTypography()
    }

    private func applyTypography() {
        guard let cell = pathControl.cell as? NSPathCell else { return }
        cell.controlSize = .regular
        cell.pathStyle = .standard
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        for component in cell.pathComponentCells {
            component.font = font
            component.image?.isTemplate = true
            component.backgroundColor = .clear
            component.textColor = .labelColor
        }
    }

    @objc private func handleSelection(_ sender: NSPathControl) {
        guard let item = sender.clickedPathItem,
              let index = sender.pathItems.firstIndex(of: item) else { return }
        switch index {
        case 0:
            presentConnectionsPopover()
        case 1:
            presentDatabasesPopover()
        default:
            break
        }
    }

    private func presentConnectionsPopover() {
        guard let controller = ConnectionsPopoverController(appModel: appModel()) else { return }
        showPopover(controller: controller, targetIndex: 0)
    }

    private func presentDatabasesPopover() {
        guard let controller = DatabasePopoverController(appModel: appModel(), connectionID: appModel().selectedConnectionID ?? UUID()) else { return }
        showPopover(controller: controller, targetIndex: 1)
    }

    private func showPopover(controller: NSViewController, targetIndex: Int) {
        activePopover?.performClose(nil)
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.contentViewController = controller

        let rect = rectForComponent(at: targetIndex)
        popover.show(relativeTo: rect, of: pathControl, preferredEdge: .maxY)
        activePopover = popover
    }

    private func rectForComponent(at index: Int) -> NSRect {
        guard let cell = pathControl.cell as? NSPathCell else { return pathControl.bounds }
        let cells = cell.pathComponentCells
        guard cells.indices.contains(index) else { return pathControl.bounds }
        return cell.rect(of: cells[index], withFrame: pathControl.bounds, in: pathControl)
    }

    // Access to AppModel via environment bridging
    private func appModel() -> AppModel {
        // SwiftUI environment is not available here; this is a placeholder to avoid compile errors.
        // Expect the hosting view to inject environment objects; for now, return shared static if available.
        return (NSApp.delegate as? EchoApp)?.appModel ?? AppModel()
    }
}

#else
// Non-macOS stub
struct NativeBreadcrumbNavigator: View {
    var body: some View { EmptyView() }
}
#endif
