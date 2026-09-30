import SwiftUI

/// One compact card: icon, title, time; opened, the whole message and its actions.
struct LabNHCompactCard: View {
    let notice: LabNHNotice
    let motion: LabNHExpandMotion
    @Binding var openID: String?

    var body: some View {
        let isOpen = openID == notice.id
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: notice.symbol).foregroundStyle(notice.tint)
                Text(notice.title)
                    .font(TypographyTokens.standard.weight(notice.isUnread ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: SpacingTokens.xs)
                Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(notice.server).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    LabNHMessageBlock(notice: notice)
                    LabNHActions(notice: notice)
                }
                .padding(.leading, SpacingTokens.lg)
                .modifier(LabNHExpansion(motion: motion))
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : notice.id }
    }
}

// MARK: - D · Compact cards

struct LabNHCompactCards: View {
    let notices: [LabNHNotice]
    let grouping: LabNHGrouping
    let motion: LabNHExpandMotion
    @Binding var openID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            ForEach(labNHGroups(notices, by: grouping), id: \.0) { title, group in
                LabNHGroupTitle(title: title)
                ForEach(group) { LabNHCompactCard(notice: $0, motion: motion, openID: $openID) }
            }
        }
    }
}

// MARK: - E · Attention first

struct LabNHAttentionFirst: View {
    let notices: [LabNHNotice]
    let motion: LabNHExpandMotion
    @Binding var openID: String?

    private var attention: [LabNHNotice] { notices.filter { $0.kind == .error && $0.isUnread } }
    private var rest: [LabNHNotice] { notices.filter { !($0.kind == .error && $0.isUnread) } }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            if !attention.isEmpty {
                LabNHGroupTitle(title: "Needs attention")
                ForEach(attention) { notice in
                    LabNHCompactCard(notice: notice, motion: motion, openID: $openID)
                        .overlay(alignment: .leading) {
                            Capsule().fill(ColorTokens.Status.error)
                                .frame(width: LabNHMetrics.errorEdge)
                                .padding(.vertical, SpacingTokens.xs)
                        }
                }
            }
            LabNHGroupTitle(title: "Earlier")
            VStack(spacing: SpacingTokens.none) {
                ForEach(rest) { row($0) }
            }
        }
    }

    /// A quiet list row that opens in place.
    private func row(_ notice: LabNHNotice) -> some View {
        let isOpen = openID == notice.id
        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: notice.symbol).foregroundStyle(notice.tint).font(TypographyTokens.detail)
                Text(notice.title).font(TypographyTokens.standard).lineLimit(1)
                Spacer(minLength: SpacingTokens.xs)
                Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    LabNHMessageBlock(notice: notice)
                    LabNHActions(notice: notice)
                }
                .padding(.leading, SpacingTokens.lg)
                .modifier(LabNHExpansion(motion: motion))
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xs)
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : notice.id }
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - F · Stacked by server

struct LabNHStacked: View {
    let notices: [LabNHNotice]
    let motion: LabNHExpandMotion
    @Binding var openID: String?
    @State private var fanned: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            ForEach(labNHGroups(notices, by: .server), id: \.0) { server, group in
                LabNHGroupTitle(title: server)
                if group.count > 1 && !fanned.contains(server) {
                    stack(server, group)
                } else {
                    VStack(spacing: SpacingTokens.xxs2) {
                        ForEach(group) { LabNHCompactCard(notice: $0, motion: motion, openID: $openID) }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    /// The newest card on top of the others, which peek out beneath it.
    private func stack(_ server: String, _ group: [LabNHNotice]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ZStack(alignment: .top) {
                ForEach(Array(group.prefix(3).enumerated().reversed()), id: \.element.id) { index, notice in
                    if index == 0 {
                        LabNHCompactCard(notice: notice, motion: motion, openID: .constant(nil))
                    } else {
                        RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                            .fill(ColorTokens.Background.secondary)
                            .overlay(RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
                                .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
                            .frame(height: LayoutTokens.FloatingSurface.rowHeight + SpacingTokens.xs)
                            .scaleEffect(x: 1 - CGFloat(index) * 0.05, y: 1)
                            .offset(y: CGFloat(index) * SpacingTokens.xxs)
                    }
                }
            }
            .padding(.bottom, SpacingTokens.xs)
            Text("\(group.count - 1) more")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.leading, SpacingTokens.xs)
        }
        .contentShape(Rectangle())
        .onTapGesture { fanned.insert(server) }
        .transition(.opacity)
    }
}
