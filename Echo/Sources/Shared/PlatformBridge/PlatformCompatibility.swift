import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Platform Compatibility Layer

struct PlatformCompatibility {

    // MARK: - Colors
    static var quaternaryLabel: Color {
        #if os(macOS)
        return Color(NSColor.quaternaryLabelColor)
        #else
        return Color(UIColor.quaternaryLabel)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColorTokens.Text.secondarySystemBackground)
        #endif
    }

    static var tertiarySystemBackground: Color {
        #if os(macOS)
        return Color(NSColor.unemphasizedSelectedContentBackgroundColor)
        #else
        return Color(UIColorTokens.Text.tertiarySystemBackground)
        #endif
    }

    static var separator: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator)
        #endif
    }

    // MARK: - Materials
    static var regularMaterial: Material {
        #if os(macOS)
        return .regularMaterial
        #else
        return .regularMaterial
        #endif
    }

    static var thinMaterial: Material {
        #if os(macOS)
        return .thinMaterial
        #else
        return .thinMaterial
        #endif
    }

    static var ultraThinMaterial: Material {
        #if os(macOS)
        return .ultraThinMaterial
        #else
        return .ultraThinMaterial
        #endif
    }

    // MARK: - Typography
    static var systemFont: Font {
        #if os(macOS)
        return .system(size: 13)
        #else
        return .system(size: 17)
        #endif
    }

    static var smallSystemFont: Font {
        #if os(macOS)
        return .system(size: 11)
        #else
        return .system(size: 15)
        #endif
    }

    static var largeSystemFont: Font {
        #if os(macOS)
        return .system(size: 15)
        #else
        return .system(size: 19)
        #endif
    }

    // MARK: - Spacing
    static var defaultPadding: CGFloat {
        #if os(macOS)
        return 8
        #else
        return 16
        #endif
    }

    static var largePadding: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 24
        #endif
    }

    static var smallPadding: CGFloat {
        #if os(macOS)
        return 4
        #else
        return 8
        #endif
    }

    // MARK: - Control Sizes
    static var buttonHeight: CGFloat {
        #if os(macOS)
        return 32
        #else
        return 44
        #endif
    }

    static var iconSize: CGFloat {
        #if os(macOS)
        return 16
        #else
        return 22
        #endif
    }

    static var largeIconSize: CGFloat {
        #if os(macOS)
        return 24
        #else
        return 32
        #endif
    }

    // MARK: - Corner Radius
    static var defaultCornerRadius: CGFloat {
        #if os(macOS)
        return 6
        #else
        return 12
        #endif
    }

    static var largeCornerRadius: CGFloat {
        #if os(macOS)
        return 12
        #else
        return 16
        #endif
    }
}

// MARK: - Cross-Platform View Modifiers

struct PlatformAdaptive: ViewModifier {
    let macOSModifier: (AnyView) -> AnyView
    let iOSModifier: (AnyView) -> AnyView

    init<M: ViewModifier, I: ViewModifier>(
        macOS: M,
        iOS: I
    ) {
        self.macOSModifier = { AnyView($0.modifier(macOS)) }
        self.iOSModifier = { AnyView($0.modifier(iOS)) }
    }

    func body(content: Content) -> some View {
        #if os(macOS)
        macOSModifier(AnyView(content))
        #else
        iOSModifier(AnyView(content))
        #endif
    }
}

extension View {
    func platformAdaptive<M: ViewModifier, I: ViewModifier>(
        macOS: M,
        iOS: I
    ) -> some View {
        modifier(PlatformAdaptive(macOS: macOS, iOS: iOS))
    }
}

// MARK: - Cross-Platform Button Styles

struct PlatformButtonStyle: ButtonStyle {
    let prominent: Bool

    init(prominent: Bool = false) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PlatformCompatibility.defaultPadding)
            .padding(.vertical, PlatformCompatibility.smallPadding)
            .background(
                RoundedRectangle(cornerRadius: PlatformCompatibility.defaultCornerRadius)
                    .fill(prominent ? ColorTokens.accent : PlatformCompatibility.secondarySystemBackground)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundStyle(prominent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Cross-Platform Card Style

struct PlatformCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(
        cornerRadius: CGFloat = PlatformCompatibility.defaultCornerRadius,
        padding: CGFloat = PlatformCompatibility.defaultPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PlatformCompatibility.regularMaterial)
            )
            #if os(iOS)
            .shadow(radius: 1)
            #endif
    }
}

// MARK: - Cross-Platform List Style

struct PlatformListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .listStyle(.sidebar)
            #else
            .listStyle(.insetGrouped)
            #endif
    }
}

extension View {
    func platformListStyle() -> some View {
        modifier(PlatformListStyle())
    }
}

// MARK: - Cross-Platform Navigation

struct PlatformNavigationView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            content
        } detail: {
            Text("Select an item")
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        #else
        NavigationStack {
            content
        }
        #endif
    }
}

// MARK: - Cross-Platform Toolbar

struct PlatformToolbar<ToolbarContent: View>: ViewModifier {
    let toolbarContent: ToolbarContent

    init(@ViewBuilder content: () -> ToolbarContent) {
        self.toolbarContent = content()
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarContent
                }
                #else
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    toolbarContent
                }
                #endif
            }
    }
}

// MARK: - Cross-Platform Context Menu

extension View {
    func platformContextMenu<MenuItems: View>(
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        #if os(macOS)
        self.contextMenu {
            menuItems()
        }
        #else
        self.contextMenu {
            menuItems()
        }
        #endif
    }
}

// MARK: - Cross-Platform Hover Effects

struct PlatformHoverEffect: ViewModifier {
    @State private var isHovering = false
    let action: (Bool) -> Void

    init(action: @escaping (Bool) -> Void) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                    action(hovering)
                }
            }
            #else
            // iOS doesn't have hover, so we don't apply the modifier
            #endif
    }
}

extension View {
    func platformHover(perform action: @escaping (Bool) -> Void) -> some View {
        modifier(PlatformHoverEffect(action: action))
    }
}

// MARK: - Cross-Platform Clipboard

struct PlatformClipboard {
    static func copy(_ string: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }

    static func paste() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}
