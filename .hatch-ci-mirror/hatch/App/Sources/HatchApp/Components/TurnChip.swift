import SwiftUI
import HatchCore

/// The phase glyph, coloured by whose turn it is, and the status name in normal text (decisions A5 and LK1).
struct StatusChip: View {
    let status: Status

    var body: some View {
        Label {
            Text(status.displayName)
                .font(.callout)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: status.phaseSymbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Theme.color(for: status.turn))
        }
        .labelStyle(.titleAndIcon)
        .fixedSize()
    }
}

/// A small coloured label with a name, used for the turn and for project chips.
struct TurnLabel: View {
    let turn: Turn

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.color(for: turn))
                .frame(width: 6, height: 6)
            Text(Theme.turnTitle(turn))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

struct TypeBadge: View {
    let type: TicketType
    var showName: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: Theme.symbol(for: type))
                .font(.caption)
            if showName {
                Text(type.displayName)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

/// A neutral rounded chip (project, area, theme).
struct PlainChip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text).font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12), in: Capsule())
        .fixedSize()
    }
}

/// The bar at the top of a ticket: who has the turn, what is expected, and the button for it (decision F2).
struct TurnBanner: View {
    let turn: Turn
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Theme.turnTitle(turn))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.color(for: turn))
                Text(message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .tint(Theme.color(for: turn))
                    .controlSize(.large)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(Theme.background(for: turn), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) { Rectangle().fill(Theme.color(for: turn)).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Wraps its children onto new lines when the row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth: CGFloat = proposal.width ?? CGFloat.infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A titled block with a quiet background, used across the ticket tabs.
struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}
