import EchoDesignSystem
import SwiftUI

/// Publishes `EchoMotion` from the user's speed setting and the system's Reduce Motion.
/// Apply it inside the environment that carries `ProjectStore`.
struct EchoMotionProvider: ViewModifier {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.environment(
            \.echoMotion,
            EchoMotion(durationScale: projectStore.globalSettings.interfaceMotionSpeed.durationScale, reduceMotion: reduceMotion)
        )
    }
}

extension View {
    /// Makes `\.echoMotion` follow the user's settings for everything inside.
    func providesEchoMotion() -> some View {
        modifier(EchoMotionProvider())
    }
}
