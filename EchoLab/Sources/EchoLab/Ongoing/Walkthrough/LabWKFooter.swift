import SwiftUI

/// The footer at the bottom of a query tab's card, drawn as Echo draws it (BottomPanelStatusBar and
/// +Metrics, 2026-10-01): the server · database chip, the Results/Messages pill, then a glass pill per
/// entry on the right (selection, rows, time, status). Every right-hand pill is 24pt tall
/// (`LayoutTokens.Footer.chipHeight`) with 11pt text. Shared by the walkthrough rounds (31, 41).
struct LabWKFooter: View {
    var server = "dkloosql10-p · ESB_INTEGRATION"
    var showsMessages = false
    var pills: [LabWKPill] = LabWKPill.completed
    /// Something more in the row after the Results/Messages pill (round 31's ZN3).
    var afterSegments: AnyView?

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(server)
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
                .frame(height: LayoutTokens.Footer.chipHeight)
                .glassEffect(.regular, in: .capsule)
            segments
            if let afterSegments { afterSegments }
            Spacer(minLength: SpacingTokens.sm)
            HStack(spacing: SpacingTokens.xxs) {
                ForEach(pills) { pill in pill }
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.Footer.height)
    }

    private var segments: some View {
        HStack(spacing: SpacingTokens.none) {
            segment("tablecells", active: !showsMessages)
            segment("text.bubble", active: showsMessages)
        }
        .padding(LayoutTokens.Footer.pillPadding)
        .glassEffect(.regular, in: .capsule)
    }

    private func segment(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(TypographyTokens.detail)
            .foregroundStyle(active ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .frame(width: LayoutTokens.Footer.segmentWidth, height: LayoutTokens.Footer.chipHeight - LayoutTokens.Footer.pillPadding * 2)
            .background { if active { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
    }
}

/// One glass pill on the footer's right. `content` is what it says; tapping calls `onTap`.
struct LabWKPill: View, Identifiable {
    let id: String
    let content: AnyView
    var help = ""
    var onTap: (() -> Void)?

    init<V: View>(id: String, help: String = "", onTap: (() -> Void)? = nil, @ViewBuilder content: () -> V) {
        self.id = id
        self.help = help
        self.onTap = onTap
        self.content = AnyView(content())
    }

    var body: some View {
        content
            .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
            .frame(height: LayoutTokens.Footer.chipHeight)
            .glassEffect(onTap == nil ? .regular : .regular.interactive(), in: .capsule)
            .contentShape(Capsule())
            .onTapGesture { onTap?() }
            .help(help)
    }

    /// "3 rows": a monospaced medium number, then a tertiary word.
    static func rows(_ count: String, label: String = "rows", onTap: (() -> Void)? = nil) -> LabWKPill {
        LabWKPill(id: "rows", onTap: onTap) {
            HStack(spacing: SpacingTokens.xxxs) {
                Text(count).font(TypographyTokens.detail.monospaced().weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                Text(label).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    static func time(_ text: String, onTap: (() -> Void)? = nil) -> LabWKPill {
        LabWKPill(id: "time", onTap: onTap) {
            Text(text).font(TypographyTokens.detail.monospaced().weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    /// The status: a dot in the tint and a secondary word.
    static func status(_ label: String, tint: Color, onTap: (() -> Void)? = nil) -> LabWKPill {
        LabWKPill(id: "status", onTap: onTap) {
            HStack(spacing: SpacingTokens.xxs) {
                Circle().fill(tint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                Text(label).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    static let completed: [LabWKPill] = [.rows("3"), .time("0s"), .status("Completed", tint: ColorTokens.Status.success)]
    static let ready: [LabWKPill] = [.status("Ready", tint: ColorTokens.Text.tertiary)]
}
