import SwiftUI

/// Bookmarks as Echo draws them today (BookmarksSidebarView, BookmarkSidebarRow): a headline and
/// "Saved queries for …", a server picker and a Grouped pill, UPPERCASE database groups and a card
/// per bookmark with its SQL.
struct LabRTBookmarksToday: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Bookmarks").font(TypographyTokens.headline)
                    Text("Saved queries for dkloosql10-p").font(TypographyTokens.footnote).foregroundStyle(ColorTokens.Text.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Label("Grouped", systemImage: "square.grid.2x2").font(TypographyTokens.footnote)
                    .padding(.horizontal, SpacingTokens.xs2).padding(.vertical, SpacingTokens.xxs2)
                    .background(Capsule().fill(ColorTokens.Text.primary.opacity(0.05)))
            }
            .padding(.horizontal, SpacingTokens.md).padding(.top, SpacingTokens.sm)
            Divider().padding(.vertical, SpacingTokens.xs)
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    ForEach(["ESB_INTEGRATION", "ccsLDK10", "DBA"], id: \.self) { database in
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text(database).font(TypographyTokens.caption).fontWeight(.semibold).textCase(.uppercase).foregroundStyle(ColorTokens.Text.secondary)
                            ForEach(LabRTBookmark.samples.filter { $0.database == database }) { bookmark in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    Text(bookmark.title).font(TypographyTokens.standard.weight(.semibold))
                                    Text(bookmark.sql).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary).lineLimit(2)
                                }
                                .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading)
                                .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: SpacingTokens.sm))
                                .overlay(RoundedRectangle(cornerRadius: SpacingTokens.sm).strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5))
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
            }
        }
        .frame(width: 260).frame(maxHeight: .infinity).workspaceCard()
    }
}

/// A quiet two-line row: a symbol, a title and a second line, with something at the right.
struct LabRTRow: View {
    let symbol: String
    var tint: Color = ColorTokens.Text.secondary
    let title: String
    var detail: String?
    var trailing: String?
    var monoTitle = false

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: symbol).font(TypographyTokens.detail).foregroundStyle(tint).frame(width: SpacingTokens.md).padding(.top, SpacingTokens.xxxs)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(title).font(monoTitle ? TypographyTokens.detail.monospaced() : TypographyTokens.standard).lineLimit(1)
                if let detail { Text(detail).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1) }
            }
            Spacer(minLength: SpacingTokens.xxs)
            if let trailing { Text(trailing).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary) }
        }
        .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs2)
        .contentShape(Rectangle())
    }
}

/// A small heading inside a column, in the tree's section style.
struct LabRTHeading: View {
    let title: String
    var count: Int?
    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(title).font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
            if let count { Text("\(count)").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary) }
        }
        .padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxxs)
    }
}

/// A glass search capsule for a column.
struct LabRTSearch: View {
    let prompt: String
    @State private var text = ""
    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
            TextField(prompt, text: $text, prompt: Text(prompt)).textFieldStyle(.plain)
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxs)
    }
}
