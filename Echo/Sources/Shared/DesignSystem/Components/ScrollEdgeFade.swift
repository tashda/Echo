import SwiftUI

/// A top-edge fade overlay for scroll views, matching the System Settings blur effect.
/// Content scrolling under this area is visually blurred/faded out.
/// Place as an `.overlay(alignment: .top)` on the scroll view.
struct ScrollEdgeFade: View {
    var height: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: height)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }
}
