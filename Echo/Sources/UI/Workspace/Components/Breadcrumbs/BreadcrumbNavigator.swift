import SwiftUI

#if os(macOS)
import AppKit
#endif

// Import the WorkspaceChromeMetrics
extension WorkspaceChromeMetrics {}

/// Main breadcrumb navigator that displays Xcode-style breadcrumbs
struct BreadcrumbNavigator: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var layoutState: TopBarNavigatorLayoutState
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var navigationState = BreadcrumbNavigationState()
#if os(macOS)
    @State private var activePopoverController: NSViewController?
#endif

    var body: some View {
        GeometryReader { proxy in
            let availableFromLayout = layoutState.availableWidth
            let available = max(availableFromLayout > 0 ? availableFromLayout : proxy.size.width, 0)
            let centerFromLayout = layoutState.centerX
            let controlHeight = max(WorkspaceChromeMetrics.chromeBackgroundHeight, proxy.size.height)

            // Width tuned to be very close to Xcode / Safari:
            // fill most of the center region, but keep a clear margin to
            // the navigation items and primary toolbar buttons.
            let fillRatio: CGFloat = availableFromLayout > 0 ? 0.9 : 0.65
            let rawWidth = available * fillRatio
            let idealWidth = clamp(rawWidth, minWidth: 420, idealWidth: 540, maxWidth: 880)
            // Never request a pill wider than the overlay region itself.
            let target = min(idealWidth, available)

            ZStack {
                let corner = controlHeight / 2
                let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

                // Use system chrome so the pill matches Safari/Xcode.
                #if os(macOS)
                if #available(macOS 15, *) {
                    shape
                        .fill(.clear)
                        .glassEffect()
                        .frame(width: target, height: controlHeight)
                } else {
                    shape
                        .fill(.clear)
                        .background(.regularMaterial, in: shape)
                        .overlay(shape.stroke(capsuleBorder, lineWidth: 1))
                        .frame(width: target, height: controlHeight)
                }
                #else
                shape
                    .fill(.clear)
                    .background(.regularMaterial, in: shape)
                    .overlay(shape.stroke(capsuleBorder, lineWidth: 1))
                    .frame(width: target, height: controlHeight)
                #endif

                // Breadcrumb content
                HStack(spacing: 0) {
                    breadcrumbContent
                    Spacer(minLength: 0)
                    breadcrumbStatus
                }
                .padding(.horizontal, 16)
                .frame(width: target, height: controlHeight, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            }
            .frame(width: target, height: controlHeight)
            .position(
                x: centerFromLayout > 0 ? centerFromLayout : proxy.size.width / 2,
                y: proxy.size.height / 2
            )
            .backgroundPreferenceValue(BreadcrumbAnchorKey.self) { anchors in
                breadcrumbPopover(anchors: anchors)
            }
            .onAppear {
                updateBreadcrumbSegments()
            }
            .onChange(of: appModel.selectedConnectionID) { _, _ in
                updateBreadcrumbSegments()
            }
            .onChange(of: appModel.sessionManager.sessions.count) { _, _ in
                updateBreadcrumbSegments()
            }
            .onChange(of: appModel.sessionManager.activeSession?.selectedDatabaseName) { _, _ in
                updateBreadcrumbSegments()
            }
            .onChange(of: navigationState.isMenuPresented) { _, isPresented in
                if !isPresented {
                    navigationState.presentedMenuIndex = nil
#if os(macOS)
                    activePopoverController = nil
#endif
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var breadcrumbContent: some View {
        if navigationState.segments.isEmpty {
            // Default state when no connection is selected
            connectionsSegment
        } else {
            // Show segments
            ForEach(Array(navigationState.segments.enumerated()), id: \.element.id) { index, segment in
                breadcrumbSegmentView(for: segment, at: index)
            }
        }
    }

    private var connectionsSegment: some View {
        BreadcrumbSegmentView(
            segment: defaultConnectionsSegment,
            isLast: true,
            onTap: {
                defaultConnectionsSegment.action?()
            },
            onMenuTap: {
                presentMenu(for: 0, segment: defaultConnectionsSegment)
            }
        )
        .anchorPreference(key: BreadcrumbAnchorKey.self, value: .bounds) { anchor in
            [BreadcrumbAnchorInfo(index: 0, anchor: anchor)]
        }
    }

    private var defaultConnectionsSegment: BreadcrumbSegment {
        BreadcrumbSegment(
            title: "Connections",
            icon: "server.rack",
            hasMenu: true,
            isActive: true,
            isEnabled: true,
            action: nil,
            menuContent: {
                AnyView(ConnectionsBreadcrumbMenu())
            }
        )
    }

    private func breadcrumbSegmentView(for segment: BreadcrumbSegment, at index: Int) -> some View {
        BreadcrumbSegmentView(
            segment: segment,
            isLast: index == navigationState.segments.count - 1,
            onTap: {
                segment.action?()
            },
            onMenuTap: {
                presentMenu(for: index, segment: segment)
            }
        )
        .anchorPreference(key: BreadcrumbAnchorKey.self, value: .bounds) { anchor in
            [BreadcrumbAnchorInfo(index: index, anchor: anchor)]
        }
    }

    @ViewBuilder
    private var breadcrumbStatus: some View {
        if let status = statusText {
            Text(status)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func breadcrumbPopover(anchors: [BreadcrumbAnchorInfo]) -> some View {
#if os(macOS)
        if navigationState.isMenuPresented,
           let menuIndex = navigationState.presentedMenuIndex,
           let controller = activePopoverController,
           let targetAnchorInfo = anchors.first(where: { $0.index == menuIndex }) {
            GeometryReader { geometry in
                Color.clear
                    .background(
                        NativePopoverController(
                            controller: controller,
                            isPresented: $navigationState.isMenuPresented,
                            anchorRect: geometry[targetAnchorInfo.anchor]
                        )
                    )
            }
            .allowsHitTesting(false)
        }
#else
        EmptyView()
#endif
    }

    private var statusText: String? {
        guard let selectedID = appModel.selectedConnectionID else {
            return "No Connection"
        }

        let state = appModel.connectionStates[selectedID]
        switch state {
        case .testing:
            return "Testing…"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Connection Error"
        case .none:
            if appModel.sessionManager.sessionForConnection(selectedID) != nil {
                return "Connected"
            }
            return "Disconnected"
        }
    }

    private func presentMenu(for index: Int, segment: BreadcrumbSegment) {
        guard segment.hasMenu, segment.isEnabled else { return }
#if os(macOS)
        guard let controller = menuController(for: index) else { return }
        if navigationState.isMenuPresented {
            if navigationState.presentedMenuIndex == index {
                navigationState.isMenuPresented = false
                return
            }
            navigationState.isMenuPresented = false
            DispatchQueue.main.async {
                activePopoverController = controller
                navigationState.presentMenu(for: index)
            }
        } else {
            activePopoverController = controller
            navigationState.presentMenu(for: index)
        }
#else
        navigationState.presentMenu(for: index)
#endif
    }

#if os(macOS)
    private func menuController(for index: Int) -> NSViewController? {
        switch index {
        case 0:
            return ConnectionsPopoverController(appModel: appModel)
        case 1:
            guard let connectionID = appModel.selectedConnectionID else { return nil }
            return DatabasePopoverController(appModel: appModel, connectionID: connectionID)
        default:
            return nil
        }
    }
#endif

    private func updateBreadcrumbSegments() {
        let connectionTitle: String
        if let connection = appModel.selectedConnection {
            connectionTitle = connection.connectionName.isEmpty ? connection.host : connection.connectionName
        } else {
            connectionTitle = "Connections"
        }

        let connectionSegment = BreadcrumbSegment(
            title: connectionTitle,
            icon: "server.rack",
            hasMenu: true,
            isActive: true,
            isEnabled: true,
            action: nil,
            menuContent: nil
        )

        let databaseTitle: String
        let isDatabaseEnabled = appModel.selectedConnectionID != nil
        if let connectionID = appModel.selectedConnectionID,
           let session = appModel.sessionManager.sessionForConnection(connectionID),
           let databaseName = session.selectedDatabaseName,
           !databaseName.isEmpty {
            databaseTitle = databaseName
        } else {
            databaseTitle = "Databases"
        }

        let databaseSegment = BreadcrumbSegment(
            title: databaseTitle,
            icon: "cylinder.fill",
            hasMenu: true,
            isActive: isDatabaseEnabled,
            isEnabled: isDatabaseEnabled,
            action: nil,
            menuContent: nil
        )

        navigationState.updateSegments([connectionSegment, databaseSegment])
    }

    // MARK: - Styling (preserving existing TopBarNavigator styling)

    private var capsuleFill: LinearGradient {
        // Unused now that we rely on .bar material, but kept for older fallbacks.
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var capsuleBorder: Color {
        #if os(macOS)
        return Color(nsColor: .separatorColor)
        #else
        return Color.black.opacity(0.09)
        #endif
    }

    private func capsuleTopHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                (colorScheme == .dark ? Color.white.opacity(0.28) : Color.white.opacity(0.60)),
                lineWidth: 0.7
            )
            .blendMode(.screen)
            .opacity(0.85)
            .offset(y: -0.5)
    }

    private var capsuleShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.10)
    }

    private var capsuleShadowRadius: CGFloat { colorScheme == .dark ? 6.5 : 4.5 }
    private var capsuleShadowYOffset: CGFloat { colorScheme == .dark ? 2.0 : 1.0 }

    private func clamp(_ value: CGFloat, minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let clamped = max(minWidth, min(maxWidth, value))
        if clamped >= idealWidth && clamped <= maxWidth {
            return max(idealWidth, clamped)
        }
        return clamped
    }
}

// MARK: - Preference Keys for Popover Positioning

struct BreadcrumbAnchorInfo: Equatable {
    let index: Int
    let anchor: Anchor<CGRect>

    static func == (lhs: BreadcrumbAnchorInfo, rhs: BreadcrumbAnchorInfo) -> Bool {
        lhs.index == rhs.index
    }
}

struct BreadcrumbAnchorKey: PreferenceKey {
    static let defaultValue: [BreadcrumbAnchorInfo] = []
    static func reduce(value: inout [BreadcrumbAnchorInfo], nextValue: () -> [BreadcrumbAnchorInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Preference-based Popover

struct PreferenceBasedPopover: View {
    let content: AnyView
    @Binding var isPresented: Bool
    let anchorIndex: Int

    @Environment(\.breadcrumbAnchors) private var breadcrumbAnchors

    var body: some View {
        #if os(macOS)
        if isPresented, let targetAnchorInfo = breadcrumbAnchors.first(where: { $0.index == anchorIndex }) {
            GeometryReader { geometry in
                Color.clear
                    .background(
                        NativePopover(
                            content: content,
                            isPresented: $isPresented,
                            anchorRect: geometry[targetAnchorInfo.anchor]
                        )
                    )
            }
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

#if os(macOS)
struct PreferenceBasedControllerPopover: View {
    let controller: NSViewController
    @Binding var isPresented: Bool
    let anchorIndex: Int

    @Environment(\.breadcrumbAnchors) private var breadcrumbAnchors

    var body: some View {
        if isPresented, let targetAnchorInfo = breadcrumbAnchors.first(where: { $0.index == anchorIndex }) {
            GeometryReader { geometry in
                Color.clear
                    .background(
                        NativePopoverController(
                            controller: controller,
                            isPresented: $isPresented,
                            anchorRect: geometry[targetAnchorInfo.anchor]
                        )
                    )
            }
        } else {
            EmptyView()
        }
    }
}
#endif

#if os(macOS)
private final class PopoverAnchorView: NSView {
    var onWindowReady: ((NSView) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        onWindowReady?(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
private struct NativePopover: NSViewRepresentable {
    let content: AnyView
    @Binding var isPresented: Bool
    let anchorRect: CGRect

    func makeNSView(context: Context) -> NSView {
        let view = PopoverAnchorView()
        view.onWindowReady = { [weak view] _ in
            guard let view else { return }
            context.coordinator.anchorView = view
            context.coordinator.tryPresentIfNeeded()
        }
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClose = {
            isPresented = false
        }
        context.coordinator.isPresented = isPresented
        context.coordinator.anchorRect = anchorRect
        context.coordinator.content = content
        context.coordinator.tryPresentIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, NSPopoverDelegate {
        weak var anchorView: NSView?
        var popover: NSPopover?
        var onClose: (() -> Void)?
        var isPresented = false
        var anchorRect: CGRect = .zero
        var content: AnyView?

        func popoverDidClose(_ notification: Notification) {
            popover = nil
            onClose?()
        }

        func tryPresentIfNeeded() {
            guard let anchorView else { return }

            if !isPresented {
                popover?.performClose(nil)
                popover = nil
                return
            }

            guard anchorView.window != nil else { return }
            guard !anchorRect.isEmpty, !anchorRect.isNull else { return }
            guard popover == nil, let content else { return }

            let popover = NSPopover()
            let hostingController = NSHostingController(rootView: content)
            popover.contentViewController = hostingController
            popover.behavior = .semitransient
            popover.animates = true
            let appearance = anchorView.effectiveAppearance
            popover.appearance = appearance
            hostingController.view.appearance = appearance
            popover.delegate = self

            popover.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY)
            self.popover = popover
        }
    }
}
#endif

#if os(macOS)
@MainActor
private struct NativePopoverController: NSViewRepresentable {
    let controller: NSViewController
    @Binding var isPresented: Bool
    let anchorRect: CGRect

    func makeNSView(context: Context) -> NSView {
        let view = PopoverAnchorView()
        view.onWindowReady = { [weak view] _ in
            guard let view else { return }
            context.coordinator.anchorView = view
            context.coordinator.tryPresentIfNeeded()
        }
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClose = {
            isPresented = false
        }

        context.coordinator.isPresented = isPresented
        context.coordinator.anchorRect = anchorRect
        context.coordinator.controller = controller
        context.coordinator.tryPresentIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, NSPopoverDelegate {
        weak var anchorView: NSView?
        var popover: NSPopover?
        var onClose: (() -> Void)?
        var isPresented = false
        var anchorRect: CGRect = .zero
        var controller: NSViewController?

        func popoverDidClose(_ notification: Notification) {
            popover = nil
            onClose?()
        }

        func tryPresentIfNeeded() {
            guard let anchorView else { return }

            if !isPresented {
                popover?.performClose(nil)
                popover = nil
                return
            }

            guard anchorView.window != nil else { return }
            guard !anchorRect.isEmpty, !anchorRect.isNull else { return }
            guard popover == nil, let controller else { return }

            let popover = NSPopover()
            popover.contentViewController = controller
            popover.behavior = .semitransient
            popover.animates = true
            let appearance = anchorView.effectiveAppearance
            popover.appearance = appearance
            controller.view.appearance = appearance
            popover.delegate = self

            popover.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY)
            self.popover = popover
        }
    }
}
#endif

// MARK: - Environment Key

private struct BreadcrumbAnchorsKey: EnvironmentKey {
    static let defaultValue: [BreadcrumbAnchorInfo] = []
}

extension EnvironmentValues {
    var breadcrumbAnchors: [BreadcrumbAnchorInfo] {
        get { self[BreadcrumbAnchorsKey.self] }
        set { self[BreadcrumbAnchorsKey.self] = newValue }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
