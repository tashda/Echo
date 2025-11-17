import SwiftUI

// Import the WorkspaceChromeMetrics
extension WorkspaceChromeMetrics {}

/// Main breadcrumb navigator that displays Xcode-style breadcrumbs
struct BreadcrumbNavigator: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var navigationState = BreadcrumbNavigationState()

    var body: some View {
        GeometryReader { proxy in
            let available = max(proxy.size.width, 0)
            let controlHeight = max(WorkspaceChromeMetrics.chromeBackgroundHeight, proxy.size.height)
            let target = clamp(available * 0.6, minWidth: 350, idealWidth: 450, maxWidth: 800)

            ZStack {
                // Capsule background (preserving existing TopBarNavigator styling)
                let corner = controlHeight / 2
                let base = RoundedRectangle(cornerRadius: corner, style: .continuous)

                base
                    .fill(capsuleFill)
                    .overlay(
                        base.stroke(capsuleBorder, lineWidth: 1)
                    )
                    .overlay(capsuleTopHighlight(cornerRadius: corner))
                    .shadow(color: capsuleShadowColor, radius: capsuleShadowRadius, y: capsuleShadowYOffset)
                    .frame(width: target, height: controlHeight)

                // Breadcrumb content
                HStack(spacing: 0) {
                    breadcrumbContent
                }
                .padding(.horizontal, 16)
                .frame(width: target, height: controlHeight)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onAppear {
                updateBreadcrumbSegments()
            }
            .onChange(of: appModel.selectedConnectionID) { _, _ in
                updateBreadcrumbSegments()
            }
            .onChange(of: appModel.sessionManager.sessions.count) { _, _ in
                updateBreadcrumbSegments()
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
        HStack(spacing: 0) {
            BreadcrumbSegmentView(
                segment: defaultConnectionsSegment,
                isLast: true,
                onTap: {
                    navigationState.presentMenu(for: 0)
                },
                onMenuTap: {
                    navigationState.presentMenu(for: 0)
                }
            )
        }
    }

    private var defaultConnectionsSegment: BreadcrumbSegment {
        BreadcrumbSegment(
            title: "Connections",
            icon: "server.rack",
            hasMenu: true,
            isActive: true,
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
                if segment.hasMenu {
                    navigationState.presentMenu(for: index)
                }
            }
        )
        .anchorPreference(key: BreadcrumbAnchorKey.self, value: .bounds) { anchor in
            [BreadcrumbAnchorInfo(index: index, anchor: anchor)]
        }
    }

    private func updateBreadcrumbSegments() {
        var segments: [BreadcrumbSegment] = []

        // Always show Connections breadcrumb
        segments.append(
            BreadcrumbSegment(
                title: "Connections",
                icon: "server.rack",
                hasMenu: true,
                isActive: appModel.selectedConnectionID == nil,
                action: {
                    // Deselect current connection
                    appModel.selectedConnectionID = nil
                },
                menuContent: {
                    AnyView(ConnectionsBreadcrumbMenu())
                }
            )
        )

        // Add Database breadcrumb if a connection is selected
        if let connectionID = appModel.selectedConnectionID,
           let session = appModel.sessionManager.sessionForConnection(connectionID),
           let databaseName = session.selectedDatabaseName {
            segments.append(
                BreadcrumbSegment(
                    title: databaseName,
                    icon: "cylinder.fill",
                    hasMenu: true,
                    isActive: true,
                    action: {
                        // Focus on database (could show database details)
                    },
                    menuContent: {
                        AnyView(DatabaseBreadcrumbMenu(connectionID: connectionID))
                    }
                )
            )
        } else if appModel.selectedConnectionID != nil {
            // Connection selected but no database
            segments.append(
                BreadcrumbSegment(
                    title: "Select Database",
                    icon: "cylinder",
                    hasMenu: true,
                    isActive: true,
                    action: {
                        // Could show database picker
                    },
                    menuContent: {
                        AnyView(DatabaseBreadcrumbMenu(connectionID: appModel.selectedConnectionID!))
                    }
                )
            )
        }

        navigationState.updateSegments(segments)
    }

    // MARK: - Styling (preserving existing TopBarNavigator styling)

    private var capsuleFill: LinearGradient {
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
        if colorScheme == .dark {
            return Color.white.opacity(0.16)
        }
        return Color.black.opacity(0.09)
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

struct BreadcrumbAnchorInfo {
    let index: Int
    let anchor: Anchor<CGRect>
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
private struct NativePopover: NSViewRepresentable {
    let content: AnyView
    @Binding var isPresented: Bool
    let anchorRect: CGRect

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented && context.coordinator.popover == nil {
            let popover = NSPopover()
            popover.contentViewController = NSHostingController(rootView: content)
            popover.behavior = .semitransient
            popover.animates = true
            popover.appearance = NSApp.effectiveAppearance

            // Show popover below the anchor
            popover.show(relativeTo: anchorRect, of: nsView, preferredEdge: .minY)
            context.coordinator.popover = popover
        } else if !isPresented {
            context.coordinator.popover?.performClose(nil)
            context.coordinator.popover = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var popover: NSPopover?
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