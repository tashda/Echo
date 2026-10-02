import SwiftUI

/// Where each tab of the strip is, for the Save card to hang from (round IC, H1).
struct TabBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Publishes this tab's bounds for the Save card.
    func tabBoundsAnchor(_ id: UUID) -> some View {
        anchorPreference(key: TabBoundsPreferenceKey.self, value: .bounds) { [id: $0] }
    }

    /// Shows the Save card over the window's workspace while `AppState.saveCardRequest` is set.
    func saveCardOverlay(gutter: CGFloat) -> some View {
        modifier(SaveCardPresentation(gutter: gutter))
    }
}

/// The Save card as Echo's floating card (plan N1; round IC): it grows out of the tab it saves,
/// centred under it and kept inside the window, or, from History, out of the top-trailing corner
/// by the inspector. A click outside or Esc closes it.
private struct SaveCardPresentation: ViewModifier {
    let gutter: CGFloat

    @Environment(AppState.self) private var appState
    @Environment(\.echoMotion) private var motion

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TabBoundsPreferenceKey.self) { bounds in
                GeometryReader { proxy in
                    if let request = appState.saveCardRequest {
                        let tab = request.anchorTabID.flatMap { bounds[$0] }.map { proxy[$0] }
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { close() }
                            SaveQueryCard(request: request, onClose: close)
                                .id(request.id)
                                .onExitCommand { close() }
                                // Scaled about its own top before it moves to its place, so it
                                // grows out of the tab.
                                .transition(.scale(scale: 0.9, anchor: tab == nil ? .topTrailing : .top)
                                    .combined(with: .opacity))
                                .offset(origin(under: tab, in: proxy.size))
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                    }
                }
                .allowsHitTesting(appState.saveCardRequest != nil)
            }
            .animation(motion.standard, value: appState.saveCardRequest?.id)
    }

    private func close() {
        appState.saveCardRequest = nil
    }

    /// The card's top-leading corner: under the tab's middle, inside the window by a gutter.
    private func origin(under tab: CGRect?, in size: CGSize) -> CGSize {
        let width = FloatingSurfaceSize.medium.width
        let maxX = max(size.width - width - gutter, gutter)
        guard let tab else { return CGSize(width: maxX, height: gutter) }
        let x = min(max(tab.midX - width / 2, gutter), maxX)
        return CGSize(width: x, height: tab.maxY + SpacingTokens.xxs)
    }
}
