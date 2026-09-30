import SwiftUI

/// One toast (round 18): the icon, a bold title and the reason under it in two lines. Hovering
/// pauses it and shows the whole reason (selectable) with small buttons; a flick to the right
/// dismisses it, and × shows on hover (always on errors, which stay until dismissed).
struct StatusToastRow: View {
    let toast: StatusToastPresenter.Toast
    let presenter: StatusToastPresenter

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @Environment(\.echoMotion) private var motion
    @State private var dragOffset: CGFloat = 0

    private var isExpanded: Bool { presenter.hoveredID == toast.id }
    private var parts: NotificationMessageParts { NotificationMessageParts(toast.message) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: toast.icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(toast.style.iconColor)
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(parts.headline)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)
                    if let detail = parts.detail {
                        Text(detail)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: isExpanded)
                            .textSelection(.enabled)
                    }
                }
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
        .offset(x: dragOffset)
        .opacity(1 - Double(min(dragOffset / LayoutTokens.Toast.width, LayoutTokens.Toast.swipeFadeLimit)))
        .gesture(swipe)
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

    /// Small bordered buttons, as in the history (rounds 17 and 18).
    private var actions: some View {
        HStack(spacing: SpacingTokens.xs) {
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
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.leading, SpacingTokens.lg)
    }

    /// A flick to the right dismisses; a short drag springs back.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: SpacingTokens.xs)
            .onChanged { value in dragOffset = max(0, value.translation.width) }
            .onEnded { value in
                if value.translation.width > LayoutTokens.Toast.swipeDismissDistance {
                    presenter.dismiss(toast.id)
                } else {
                    withAnimation(motion.standard) { dragOffset = 0 }
                }
            }
    }
}
