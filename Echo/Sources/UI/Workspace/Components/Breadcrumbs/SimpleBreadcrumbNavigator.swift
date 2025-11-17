import SwiftUI
import AppKit

/// Simplified breadcrumb navigator that displays Xcode-style breadcrumbs with native macOS popovers
struct SimpleBreadcrumbNavigator: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showConnectionsMenu = false
    @State private var showDatabaseMenu = false

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
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var breadcrumbContent: some View {
        HStack(spacing: 0) {
            // Connections breadcrumb
            SimpleBreadcrumbSegmentView(
                title: "Connections",
                icon: "server.rack",
                isActive: appModel.selectedConnectionID == nil,
                isLast: appModel.selectedConnectionID == nil,
                onMenuTap: {
                    showConnectionsMenu.toggle()
                }
            )
            .popover(isPresented: $showConnectionsMenu) {
                ConnectionsBreadcrumbMenu()
                    .frame(width: 280, height: 400)
            }

            // Database breadcrumb (only if connection is selected)
            if let connectionID = appModel.selectedConnectionID,
               let session = appModel.sessionManager.sessionForConnection(connectionID) {

                Text("›")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)

                SimpleBreadcrumbSegmentView(
                    title: session.selectedDatabaseName ?? "Select Database",
                    icon: session.selectedDatabaseName != nil ? "cylinder.fill" : "cylinder",
                    isActive: true,
                    isLast: true,
                    onMenuTap: {
                        showDatabaseMenu.toggle()
                    }
                )
                .popover(isPresented: $showDatabaseMenu) {
                    DatabaseBreadcrumbMenu(connectionID: connectionID)
                        .frame(width: 260, height: 300)
                }
            }
        }
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

/// Simplified breadcrumb segment view
struct SimpleBreadcrumbSegmentView: View {
    let title: String
    let icon: String
    let isActive: Bool
    let isLast: Bool
    let onMenuTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    private var textColor: Color {
        isActive ? .primary : .primary.opacity(0.8)
    }

    private var backgroundColor: Color {
        if isPressed {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }

    private var fontWeight: Font.Weight {
        isActive ? .medium : .regular
    }

    var body: some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)

            // Text
            Text(title)
                .font(.system(size: 13, weight: fontWeight))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLast {
                onMenuTap()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )

        // Menu arrow for non-last segments
        if !isLast {
            Button(action: onMenuTap) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.set()
                }
            }
        }
    }
}