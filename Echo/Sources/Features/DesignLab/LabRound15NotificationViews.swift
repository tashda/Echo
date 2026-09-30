#if DEBUG
import SwiftUI

/// A toast at one fixed width, so hovering never changes its size sideways. Hovering shows the
/// whole message (selectable) and quiet text actions; errors stay until dismissed.
struct LabToastView: View {
    let notice: LabNotice
    let center: LabNoticeCenter

    private var isExpanded: Bool { center.hoveredToast == notice.id }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: notice.symbol).foregroundStyle(notice.tint)
                Text(notice.title)
                    .font(TypographyTokens.standard.weight(.medium))
                    .lineLimit(1)
                if notice.count > 1 {
                    Text("×\(notice.count)").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer(minLength: SpacingTokens.none)
                Button { center.dismiss(notice.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .opacity(isExpanded ? 1 : 0)
                    .help("Dismiss")
            }
            if isExpanded {
                Text(notice.detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, SpacingTokens.lg)
                LabNoticeActions(notice: notice)
                    .padding(.leading, SpacingTokens.lg)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .frame(width: LabRound15NoticeMetrics.toastWidth, alignment: .leading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius))
        .onHover { inside in
            if inside { center.hoveredToast = notice.id } else if center.hoveredToast == notice.id { center.hoveredToast = nil }
        }
    }
}

/// Quiet text actions: Copy always, Open Tab when the tab is still open.
struct LabNoticeActions: View {
    let notice: LabNotice

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            if notice.canOpenTab { Button("Open Tab") {} }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(notice.title)\n\(notice.detail)", forType: .string)
            }
        }
        .buttonStyle(.plain)
        .font(TypographyTokens.detail.weight(.medium))
        .foregroundStyle(ColorTokens.accent)
    }
}

/// The history as a list grouped by server. A row opens inline with the whole message; nothing is
/// greyed out, whether or not its tab still exists.
struct LabNoticeList: View {
    let center: LabNoticeCenter
    var selection: Binding<UUID?>?

    var body: some View {
        let servers = Array(NSOrderedSet(array: center.history.map(\.server))) as? [String] ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                ForEach(servers, id: \.self) { server in
                    Text(server)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.top, SpacingTokens.xs)
                        .padding(.horizontal, SpacingTokens.xs)
                    ForEach(center.history.filter { $0.server == server }) { notice in
                        row(notice)
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func row(_ notice: LabNotice) -> some View {
        let isOpen = selection == nil ? center.expandedItem == notice.id : selection?.wrappedValue == notice.id
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: notice.symbol).foregroundStyle(notice.tint)
                Text(notice.title).font(TypographyTokens.standard).lineLimit(isOpen ? nil : 1)
                Spacer(minLength: SpacingTokens.xs)
                Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen && selection == nil {
                Text(notice.detail)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, SpacingTokens.lg)
                LabNoticeActions(notice: notice).padding(.leading, SpacingTokens.lg)
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(isOpen ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius))
        .contentShape(Rectangle())
        .onTapGesture {
            if let selection {
                selection.wrappedValue = notice.id
            } else {
                center.expandedItem = isOpen ? nil : notice.id
            }
        }
    }
}

/// The history's header: title, filter menu and Clear.
struct LabNoticeHeader: View {
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Notifications").font(TypographyTokens.headline)
            Spacer(minLength: SpacingTokens.none)
            Menu {
                Button("All") {}
                Button("Errors") {}
                Button("Connections") {}
                Button("Queries") {}
                Button("Jobs") {}
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Button("Clear") {}
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.accent)
        }
        .font(TypographyTokens.standard)
    }
}
#endif
