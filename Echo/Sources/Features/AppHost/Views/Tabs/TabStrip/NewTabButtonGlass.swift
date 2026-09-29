import SwiftUI

/// The classic + has its own glass circle; inside the glass capsule it has none, so glass
/// never sits on glass.
struct NewTabButtonGlass: ViewModifier {
    let isInsideCapsule: Bool

    func body(content: Content) -> some View {
        if isInsideCapsule {
            content
        } else {
            content.glassEffect(.regular, in: .circle)
        }
    }
}
