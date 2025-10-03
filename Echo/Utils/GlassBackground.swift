import SwiftUI
import AppKit

// MARK: - Modern Liquid Glass Implementation
struct LiquidGlassBackground: NSViewRepresentable {
    let tintColor: NSColor?
    let interactive: Bool
    
    init(tintColor: NSColor? = nil, interactive: Bool = false) {
        self.tintColor = tintColor
        self.interactive = interactive
    }
    
    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.tintColor = tintColor
        return glassView
    }
    
    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.tintColor = tintColor
    }
}

// MARK: - Glass Effect Container for Multiple Elements
struct LiquidGlassContainer<Content: View>: NSViewRepresentable {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSGlassEffectContainerView {
        let containerView = NSGlassEffectContainerView()
        containerView.spacing = spacing
        
        // Create SwiftUI hosting view for content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView = hostingView
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSGlassEffectContainerView, context: Context) {
        nsView.spacing = spacing
        if let hostingView = nsView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - Liquid Glass Modifiers
extension View {
    /// Applies modern Liquid Glass effect with optional tinting and interactivity
    func liquidGlass(tint: Color? = nil, interactive: Bool = false) -> some View {
        self.background {
            LiquidGlassBackground(
                tintColor: tint.map { NSColor($0) },
                interactive: interactive
            )
        }
    }
    
    /// Creates a container for multiple Liquid Glass elements that can merge
    func liquidGlassContainer(spacing: CGFloat = 0) -> some View {
        LiquidGlassContainer(spacing: spacing) {
            self
        }
    }
}

