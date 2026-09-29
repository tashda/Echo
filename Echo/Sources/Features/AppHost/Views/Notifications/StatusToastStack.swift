import SwiftUI

/// The toast stack (plan N2): up to three glass toasts that melt together. Hovering one pauses it
/// and expands it into a card with the full message and its actions.
struct StatusToastStack: View {
    let presenter: StatusToastPresenter
    let onShowHistory: () -> Void

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.echoMotion) private var motion

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.sm) {
            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                ForEach(presenter.toasts) { toast in
                    toastView(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(motion.standard, value: presenter.toasts)
        .animation(motion.standard, value: presenter.hoveredID)
    }

    private func toastView(_ toast: StatusToastPresenter.Toast) -> some View {
        let isExpanded = presenter.hoveredID == toast.id
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: toast.icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(toast.style.iconColor)
                Text(toast.message)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isExpanded)
                if toast.count > 1 {
                    Text("×\(toast.count)")
                        .font(TypographyTokens.detail.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if isExpanded { actions(for: toast) }
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.xs)
        .frame(width: isExpanded ? LayoutTokens.FloatingSurface.mediumWidth : nil, alignment: .leading)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: isExpanded ? LayoutTokens.FloatingSurface.cornerRadius : LayoutTokens.Toast.cornerRadius, style: .continuous)
        )
        .onHover { inside in
            if inside {
                presenter.hoveredID = toast.id
            } else if presenter.hoveredID == toast.id {
                presenter.hoveredID = nil
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Dismiss") { presenter.dismiss(toast.id) }
    }

    private func actions(for toast: StatusToastPresenter.Toast) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            if environmentState.canReveal(toast.context) {
                Button(toast.context?.tabID != nil ? "Open Tab" : "Show Server") {
                    environmentState.reveal(toast.context)
                    presenter.dismiss(toast.id)
                }
                .buttonStyle(.glass)
            }
            Button("Show All") {
                presenter.dismiss(toast.id)
                onShowHistory()
            }
            .buttonStyle(.glass)
            Spacer(minLength: SpacingTokens.none)
            Button {
                presenter.dismiss(toast.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ColorTokens.Text.secondary)
            .help("Dismiss")
            .accessibilityLabel("Dismiss")
        }
        .controlSize(.small)
    }
}
