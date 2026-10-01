// Copied from Echo/Sources/Shared/DesignSystem/Components/AdaptiveWorkspaceCard.swift (whole file). Original stays in Echo until the Design Lab is removed.
import SwiftUI

/// True when a view holds at least one workspace card. Every card reports it, so a container
/// can tell whether its content already lays out its own cards (TT1: panes are cards).
struct ContainsWorkspaceCardKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// The card's clip: its rounded shape, or, while the card has no chrome, a rectangle wide enough
/// for the inner cards' shadows.
struct WorkspaceCardClipShape: Shape {
    let cornerRadius: CGFloat
    let clips: Bool

    func path(in rect: CGRect) -> Path {
        guard clips else {
            let allowance = ShadowTokens.workspaceCard.radius * 2
            return Path(rect.insetBy(dx: -allowance, dy: -allowance))
        }
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}

/// A workspace card for content that is sometimes one pane and sometimes several: a card while
/// the content is a single pane, no chrome at all once the content puts its panes on cards of
/// their own (Design/05-components › Tool tabs, TT1). Changing between the two keeps the
/// content's identity, so its state survives a page switch.
struct AdaptiveWorkspaceCardModifier: ViewModifier {
    @State private var contentHasCards = false

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ContainsWorkspaceCardKey.self) { contentHasCards = $0 }
            .modifier(WorkspaceCardModifier(chromeOpacity: contentHasCards ? 0 : 1, clipsContent: !contentHasCards))
    }
}

extension View {
    /// Puts the view on a workspace card unless it lays out cards of its own.
    func adaptiveWorkspaceCard() -> some View {
        modifier(AdaptiveWorkspaceCardModifier())
    }
}
