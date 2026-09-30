import SwiftUI

/// The toast stack (plan N2, round 15): up to three glass toasts at one fixed width that melt
/// together. Hovering one pauses it and opens it in place to the whole message, selectable, with
/// quiet text actions; errors stay until dismissed.
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
        .animation(motion.standard, value: presenter.toasts)
        .animation(motion.standard, value: presenter.hoveredID)
    }
}

private struct StatusToastRow: View {
    let toast: StatusToastPresenter.Toast
    let presenter: StatusToastPresenter

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    private var isExpanded: Bool { presenter.hoveredID == toast.id }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: toast.icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(toast.style.iconColor)
                Text(toast.message)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(isExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isExpanded)
                    .textSelection(.enabled)
                if toast.count > 1 {
                    Text("×\(toast.count)")
                        .font(TypographyTokens.detail.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer(minLength: SpacingTokens.none)
                Button { presenter.dismiss(toast.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .opacity(isExpanded || toast.staysUntilDismissed ? 1 : 0)
                    .help("Dismiss")
                    .accessibilityLabel("Dismiss")
            }
            if isExpanded { actions }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .frame(width: LayoutTokens.Toast.width, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: LayoutTokens.Toast.cornerRadius, style: .continuous))
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

    /// Quiet text actions, lined up under the message.
    private var actions: some View {
        HStack(spacing: SpacingTokens.sm) {
            if environmentState.canReveal(toast.context) {
                Button(toast.context?.tabID != nil ? "Open Tab" : "Show Server") {
                    environmentState.reveal(toast.context)
                    presenter.dismiss(toast.id)
                }
            }
            Button("Copy") { copyToGeneralPasteboard(toast.message) }
            Button("Show All") {
                presenter.dismiss(toast.id)
                appState.showNotificationHistory()
            }
        }
        .buttonStyle(.plain)
        .font(TypographyTokens.detail.weight(.medium))
        .foregroundStyle(ColorTokens.accent)
        .padding(.leading, SpacingTokens.lg)
    }
}
