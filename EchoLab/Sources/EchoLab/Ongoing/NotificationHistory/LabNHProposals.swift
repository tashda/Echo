import SwiftUI

/// Groups notices by day or by server, keeping their order.
func labNHGroups(_ notices: [LabNHNotice], by grouping: LabNHGrouping) -> [(String, [LabNHNotice])] {
    var order: [String] = []
    var groups: [String: [LabNHNotice]] = [:]
    for notice in notices {
        let key = grouping == .time ? notice.day : notice.server
        if groups[key] == nil { order.append(key) }
        groups[key, default: []].append(notice)
    }
    return order.map { ($0, groups[$0] ?? []) }
}

// MARK: - A · Timeline

struct LabNHTimeline: View {
    let notices: [LabNHNotice]
    let grouping: LabNHGrouping
    let motion: LabNHExpandMotion
    @Binding var openID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            ForEach(labNHGroups(notices, by: grouping), id: \.0) { title, group in
                LabNHGroupTitle(title: title)
                ForEach(Array(group.enumerated()), id: \.element.id) { index, notice in
                    row(notice, isLast: index == group.count - 1)
                }
            }
        }
    }

    private func row(_ notice: LabNHNotice, isLast: Bool) -> some View {
        let isOpen = openID == notice.id
        return HStack(alignment: .top, spacing: SpacingTokens.xs) {
            // The time line: a dot in the event's colour, joined to the next.
            VStack(spacing: SpacingTokens.none) {
                Circle().fill(notice.tint).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                    .padding(.top, SpacingTokens.xxs2)
                if !isLast { Rectangle().fill(ColorTokens.Text.quaternary).frame(width: 1) }
            }
            .frame(width: LabNHMetrics.timelineRail)
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notice.title).font(TypographyTokens.standard.weight(notice.isUnread ? .semibold : .regular))
                    Spacer(minLength: SpacingTokens.xs)
                    Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
                Text(grouping == .time ? notice.server : notice.message)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                if isOpen {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        LabNHMessageBlock(notice: notice)
                        LabNHActions(notice: notice)
                    }
                    .padding(.top, SpacingTokens.xxs)
                    .modifier(LabNHExpansion(motion: motion))
                }
            }
            .padding(.bottom, SpacingTokens.sm)
        }
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : notice.id }
    }
}

// MARK: - B · Cards

struct LabNHCards: View {
    let notices: [LabNHNotice]
    let grouping: LabNHGrouping
    let motion: LabNHExpandMotion
    @Binding var openID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            ForEach(labNHGroups(notices, by: grouping), id: \.0) { title, group in
                LabNHGroupTitle(title: title)
                ForEach(group) { card($0) }
            }
        }
    }

    private func card(_ notice: LabNHNotice) -> some View {
        let isOpen = openID == notice.id
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: notice.symbol).foregroundStyle(notice.tint)
                Text(notice.title).font(TypographyTokens.standard.weight(.medium)).lineLimit(1)
                Spacer(minLength: SpacingTokens.xs)
                if notice.isUnread { Circle().fill(ColorTokens.accent).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2) }
                Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            Text(isOpen ? notice.server : notice.message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(isOpen ? 1 : 2)
                .padding(.leading, SpacingTokens.lg)
            if isOpen {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    LabNHMessageBlock(notice: notice)
                    LabNHActions(notice: notice)
                }
                .padding(.leading, SpacingTokens.lg)
                .modifier(LabNHExpansion(motion: motion))
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
        .overlay(alignment: .leading) {
            if notice.kind == .error {
                Capsule().fill(ColorTokens.Status.error)
                    .frame(width: LabNHMetrics.errorEdge)
                    .padding(.vertical, SpacingTokens.xs)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : notice.id }
    }
}

// MARK: - C · List and detail

struct LabNHListDetail: View {
    let notices: [LabNHNotice]
    @Binding var openID: String?

    private var selected: LabNHNotice? { notices.first { $0.id == openID } ?? notices.first }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabNHHeader(unread: notices.filter(\.isUnread).count)
            ScrollView {
                VStack(spacing: SpacingTokens.none) {
                    ForEach(notices) { row($0) }
                }
            }
            Divider()
            if let selected {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Label(selected.title, systemImage: selected.symbol)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .foregroundStyle(selected.tint)
                    Text("\(selected.server) · \(selected.time)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    ScrollView { LabNHMessageBlock(notice: selected) }
                    LabNHActions(notice: selected)
                }
                .frame(height: LabNHMetrics.detailHeight, alignment: .top)
                .id(selected.id)
                .transition(.opacity)
            }
        }
    }

    private func row(_ notice: LabNHNotice) -> some View {
        let isSelected = selected?.id == notice.id
        return HStack(spacing: SpacingTokens.xs) {
            Image(systemName: notice.symbol).foregroundStyle(notice.tint).font(TypographyTokens.detail)
            Text(notice.title).font(TypographyTokens.standard.weight(notice.isUnread ? .semibold : .regular)).lineLimit(1)
            Spacer(minLength: SpacingTokens.xs)
            Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.FloatingSurface.rowHeight)
        .background(isSelected ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { openID = notice.id }
    }
}
