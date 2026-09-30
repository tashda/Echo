import SwiftUI

/// The toasts, in the top-right corner of the tab's first card, inset so they never cross its
/// edge: inside the editor card on a query tab, below the tab bar, left of the inspector
/// (round 15). With no tab open they take the same corner of the canvas page.
struct ToastOverlay: ViewModifier {
    var isActive = true

    @Environment(EnvironmentState.self) private var environmentState

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if isActive {
                StatusToastStack(presenter: environmentState.toastPresenter)
                    .padding(LayoutTokens.Toast.inset)
            }
        }
    }
}

extension View {
    func toastOverlay(isActive: Bool = true) -> some View {
        modifier(ToastOverlay(isActive: isActive))
    }
}
