import SwiftUI

/// The history's header: title, unread count, filters and Clear, in the round's header style.
struct LabNHHeader: View {
    let unread: Int

    @Environment(\.labNHHeaderStyle) private var style
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Notifications").font(TypographyTokens.headline)
            count
            Spacer(minLength: SpacingTokens.none)
            trailing
        }
        .font(TypographyTokens.standard)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var count: some View {
        if unread > 0 {
            switch style {
            case .accentText:
                Text("\(unread) new").font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.accent)
            case .quietCount:
                Text("\(unread)")
                    .font(TypographyTokens.detail.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .background(ColorTokens.Workspace.groupFill, in: .capsule)
            default:
                Text("\(unread)")
                    .font(TypographyTokens.headline.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch style {
        case .accentText:
            filterMenu(symbol: "line.3.horizontal.decrease")
            Button("Clear") {}.buttonStyle(.plain).foregroundStyle(ColorTokens.accent)
        case .quietCount:
            filterMenu(symbol: "line.3.horizontal.decrease")
            Button("Clear") {}
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.secondary)
                .opacity(isHovering ? 1 : 0)
        case .titleMenu:
            Menu {
                filterItems
                Divider()
                Button("Clear All", role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Filter and Clear")
        case .iconButtons:
            filterMenu(symbol: "line.3.horizontal.decrease.circle")
            Button { } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Clear All")
        case .smallButtons:
            Menu("Filter") { filterItems }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            Button("Clear") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func filterMenu(symbol: String) -> some View {
        Menu { filterItems } label: { Image(systemName: symbol) }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Filter")
    }

    @ViewBuilder
    private var filterItems: some View {
        Button("All") {}
        Button("Errors") {}
        Button("Connections") {}
        Button("Queries") {}
        Button("Jobs") {}
    }
}

/// The whole message: selectable, in the editor font on a quiet inset.
struct LabNHMessageBlock: View {
    let notice: LabNHNotice

    var body: some View {
        Text(notice.message)
            .font(TypographyTokens.detail.monospaced())
            .foregroundStyle(ColorTokens.Text.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius / 2, style: .continuous))
    }
}

/// An opened notification's actions (its link, such as Open Tab, and Copy) in the round's
/// action style.
struct LabNHActions: View {
    let notice: LabNHNotice

    @Environment(\.labNHActionStyle) private var style

    var body: some View {
        switch style {
        case .textLinks:
            HStack(spacing: SpacingTokens.sm) { buttons }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.accent)
        case .smallButtons:
            HStack(spacing: SpacingTokens.xs) { buttons }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .glass:
            HStack(spacing: SpacingTokens.xs) { buttons }
                .buttonStyle(.glass)
                .controlSize(.small)
        case .icons:
            HStack(spacing: SpacingTokens.xs) {
                if let link = notice.link {
                    LabNHIconAction(symbol: "arrow.up.right.square", help: link) {}
                }
                LabNHIconAction(symbol: "doc.on.doc", help: "Copy", action: copy)
            }
        case .menu:
            Menu {
                if let link = notice.link { Button(link) {} }
                Button("Copy Message", action: copy)
                Button("Copy Details") {}
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if let link = notice.link { Button(link) {} }
        Button("Copy", action: copy)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(notice.title)\n\(notice.message)", forType: .string)
    }
}

/// A quiet icon that brightens under the pointer.
private struct LabNHIconAction: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.plain)
            .foregroundStyle(isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .onHover { isHovering = $0 }
            .help(help)
    }
}

/// A group title: a day or a server.
struct LabNHGroupTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.top, SpacingTokens.xs)
    }
}

/// How a style shows the opened part of a row.
struct LabNHExpansion: ViewModifier {
    let motion: LabNHExpandMotion

    func body(content: Content) -> some View {
        content.transition(motion == .grow
            ? .asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity)
            : .opacity)
    }
}

/// The column as Echo has it today: a grouped box per server, rows opening in place.
struct LabNHTodayColumn: View {
    let notices: [LabNHNotice]
    @State private var openID: String?

    var body: some View {
        let servers = notices.map(\.server).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            LabNHHeader(unread: 0)
            ForEach(servers, id: \.self) { server in
                LabNHGroupTitle(title: server)
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    ForEach(notices.filter { $0.server == server }) { notice in
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                                Image(systemName: notice.symbol).foregroundStyle(notice.tint).font(TypographyTokens.detail)
                                Text("\(notice.title): \(notice.message)")
                                    .font(TypographyTokens.standard)
                                    .lineLimit(openID == notice.id ? nil : 2)
                                Spacer(minLength: SpacingTokens.xs)
                                Text(notice.time).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            if openID == notice.id { LabNHActions(notice: notice).padding(.leading, SpacingTokens.lg) }
                        }
                        .padding(.vertical, SpacingTokens.xs)
                        .contentShape(Rectangle())
                        .onTapGesture { openID = openID == notice.id ? nil : notice.id }
                        .overlay(alignment: .bottom) { Divider() }
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
                .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius))
            }
        }
    }
}
