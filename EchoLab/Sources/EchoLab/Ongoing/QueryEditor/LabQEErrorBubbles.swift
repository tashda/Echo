import SwiftUI

/// Round 28.6 rev 3: the bubble with the error's message (the owner didn't like today's). Today's
/// is QueryErrorBubble in an NSPopover: the message with a stop symbol, the detail in grey, and a
/// Fix button when the server's hint names the right word.
enum LabQEErrorBubbleLook: String, CaseIterable {
    case today = "BB0 · Popover (today)"
    case card = "BB1 · Card with a title"
    case compact = "BB2 · One-line pill"
    case glass = "BB3 · Glass with a pointer"
    case hud = "BB4 · Dark HUD"
    case inline = "BB5 · A line under the code"
    case margin = "BB6 · A note in the margin"
    case accentEdge = "BB7 · Card with a red edge"

    var summary: String {
        switch self {
        case .today: "Material rounded box: the message with a stop symbol in red, the detail in grey, Fix below."
        case .card: "A title (“Unknown table”) in red, the message in the text colour, the detail grey, Fix as a button on the right."
        case .compact: "Just the message on a red-tinted capsule under the word; Fix as a small link at its end."
        case .glass: "A Liquid Glass bubble with a small pointer at the word, like macOS 26's popovers, with the title and Fix."
        case .hud: "A dark rounded panel with white text, like Xcode's quick help: stands out over light code."
        case .inline: "The message opens as a slim red band under the line itself, pushing nothing; Fix at its end."
        case .margin: "The message sits at the right edge on the error's line, joined to the word by a thin line."
        case .accentEdge: "A white card with a 3pt red edge on the left, title, message and Fix."
        }
    }
}

/// One error bubble, placed by the editor under the word (or at the margin for BB6).
struct LabQEErrorBubbleView: View {
    let look: LabQEErrorBubbleLook
    let title: String
    let message: String
    let detail: String
    var fix: String? = "Use customers"

    private var red: Color { ColorTokens.Status.error }

    var body: some View {
        Group {
            switch look {
            case .today:
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Label(message, systemImage: "exclamationmark.octagon.fill").foregroundStyle(red)
                    Text(detail).foregroundStyle(ColorTokens.Text.secondary)
                    if let fix { button(fix) }
                }
                .padding(SpacingTokens.xs)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
            case .card:
                HStack(alignment: .top, spacing: SpacingTokens.sm) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text(title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(red)
                        Text(message).foregroundStyle(ColorTokens.Text.primary)
                        Text(detail).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    if let fix { button(fix) }
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous).strokeBorder(ColorTokens.Separator.primary))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
            case .compact:
                HStack(spacing: SpacingTokens.xs) {
                    Text(message).foregroundStyle(red)
                    if let fix { Text(fix).foregroundStyle(ColorTokens.accent).underline() }
                }
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .background(red.opacity(0.12), in: Capsule())
            case .glass:
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Label(title, systemImage: "exclamationmark.octagon.fill").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(red)
                    Text(message)
                    HStack {
                        Text(detail).foregroundStyle(ColorTokens.Text.secondary)
                        if let fix { button(fix) }
                    }
                }
                .padding(SpacingTokens.sm)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.md, style: .continuous))
                .overlay(alignment: .topLeading) {
                    LabQEPointer().fill(.regularMaterial).frame(width: SpacingTokens.sm, height: SpacingTokens.xxs2)
                        .offset(x: SpacingTokens.md, y: -SpacingTokens.xxs2)
                }
            case .hud:
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(red)
                    Text(message).foregroundStyle(.white)
                    HStack {
                        Text(detail).foregroundStyle(.white.opacity(0.6))
                        if let fix { button(fix).environment(\.colorScheme, .dark) }
                    }
                }
                .padding(SpacingTokens.sm)
                .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
            case .inline, .margin:
                HStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(red)
                    Text(message).foregroundStyle(ColorTokens.Text.primary)
                    if let fix { button(fix) }
                }
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .background(red.opacity(look == .inline ? 0.1 : 0.08), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous))
            case .accentEdge:
                HStack(alignment: .top, spacing: SpacingTokens.xs) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text(title).font(TypographyTokens.detail.weight(.semibold))
                        Text(message).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    if let fix { button(fix) }
                }
                .padding(SpacingTokens.sm)
                .padding(.leading, SpacingTokens.xxs)
                .background(ColorTokens.Workspace.card, in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: SpacingTokens.xs, bottomLeadingRadius: SpacingTokens.xs).fill(red).frame(width: SpacingTokens.nano)
                }
                .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
            }
        }
        .font(TypographyTokens.detail)
        .fixedSize()
        .allowsHitTesting(false)
    }

    private func button(_ title: String) -> some View {
        Text(title)
            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.micro)
            .background(ColorTokens.Text.primary.opacity(0.08), in: Capsule())
    }
}

/// The small triangle that points a bubble at its word.
struct LabQEPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
