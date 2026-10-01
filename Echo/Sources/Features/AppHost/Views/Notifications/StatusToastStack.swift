import SwiftUI

/// The toast stack (plan N2, rounds 15 and 18): up to three glass toasts at one fixed width that
/// melt together, dropping in from the top.
struct StatusToastStack: View {
    let presenter: StatusToastPresenter

    @Environment(\.echoMotion) private var motion

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.sm) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                ForEach(presenter.toasts) { toast in
                    StatusToastRow(toast: toast, presenter: presenter)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .conformanceTag("toast.stack")
        .animation(motion.standard, value: presenter.toasts)
        .animation(motion.standard, value: presenter.hoveredID)
    }
}
