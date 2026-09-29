import SwiftUI

/// The one width scale for floating surfaces: cards, and the system popovers that stay (plan N5).
enum FloatingSurfaceSize {
    case small, medium, large

    var width: CGFloat {
        switch self {
        case .small: LayoutTokens.FloatingSurface.smallWidth
        case .medium: LayoutTokens.FloatingSurface.mediumWidth
        case .large: LayoutTokens.FloatingSurface.largeWidth
        }
    }
}

extension View {
    /// Content of a system popover on the floating-surface tokens: one padding, one width scale.
    func floatingSurfaceContent(_ size: FloatingSurfaceSize) -> some View {
        padding(LayoutTokens.FloatingSurface.padding)
            .frame(width: size.width, alignment: .leading)
    }
}

/// Echo's in-window floating card (plan N1): glass, no arrow, the floating-surface sizes, padding
/// and corners. It grows out of the corner it's anchored to and closes on a click outside or Esc.
/// Autocomplete and the database switcher use the system popover instead (05-components).
struct FloatingCard<Content: View>: View {
    var size: FloatingSurfaceSize = .medium
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            content
        }
        .padding(LayoutTokens.FloatingSurface.padding)
        .frame(width: size.width, alignment: .leading)
        // Glass on the card, not a GlassEffectContainer around text fields (round 10's autofill hang).
        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
    }
}

/// Shows a floating card over this view, anchored to `alignment`, above a clear layer that closes
/// it on a click outside. Esc closes it too.
private struct FloatingCardPresentation<Card: View>: ViewModifier {
    @Binding var isPresented: Bool
    let alignment: Alignment
    let insets: EdgeInsets
    @ViewBuilder let card: () -> Card

    @Environment(\.echoMotion) private var motion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if isPresented {
                    ZStack(alignment: alignment) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { isPresented = false }
                        card()
                            .padding(insets)
                            .onExitCommand { isPresented = false }
                            .transition(.scale(scale: 0.9, anchor: alignment.unitPoint).combined(with: .opacity))
                    }
                }
            }
            .animation(motion.standard, value: isPresented)
    }
}

extension View {
    func floatingCard<Card: View>(
        isPresented: Binding<Bool>,
        alignment: Alignment = .topTrailing,
        insets: EdgeInsets = EdgeInsets(),
        @ViewBuilder card: @escaping () -> Card
    ) -> some View {
        modifier(FloatingCardPresentation(isPresented: isPresented, alignment: alignment, insets: insets, card: card))
    }
}

private extension Alignment {
    var unitPoint: UnitPoint {
        switch self {
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        default: .center
        }
    }
}
