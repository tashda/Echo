import SwiftUI

/// The history's header: title, unread count, filter menu and Clear.
struct LabNHHeader: View {
    let unread: Int

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Notifications").font(TypographyTokens.headline)
            if unread > 0 {
                Text("\(unread) new")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.accent)
            }
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
            .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius / 2, style: .continuous))
    }
}

/// Quiet text actions: the event's link (Open Tab, Show Server) and Copy.
struct LabNHActions: View {
    let notice: LabNHNotice

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            if let link = notice.link { Button(link) {} }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(notice.title)\n\(notice.message)", forType: .string)
            }
        }
        .buttonStyle(.plain)
        .font(TypographyTokens.detail.weight(.medium))
        .foregroundStyle(ColorTokens.accent)
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
                .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius))
            }
        }
    }
}
