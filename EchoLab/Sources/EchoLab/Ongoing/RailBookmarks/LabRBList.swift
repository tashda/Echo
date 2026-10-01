import SwiftUI

/// The proposed list: all servers, folders, search, selected bookmark's SQL.
struct LabRBList: View {
    let look: RailBookmarksRound.ListLook
    let folders: Bool
    @State private var selected = "b2"

    var body: some View {
        if look == .inline || look == .detail {
            LabRBNativeList(look: look).frame(width: 300).workspaceCard()
        } else if look == .today {
            LabRTBookmarksToday()
        } else {
            LabRTColumn(title: "Bookmarks", subtitle: "\(LabRTBookmark.samples.count) saved", trailing: AnyView(Image(systemName: "folder.badge.plus").foregroundStyle(ColorTokens.Text.secondary))) {
                LabRTSearch(prompt: "Search bookmarks")
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(groups, id: \.0) { title, items in
                            LabRTHeading(title: title, count: items.count)
                            ForEach(items) { bookmark in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    LabRTRow(symbol: "bookmark", title: bookmark.title, detail: "\(bookmark.server) · \(bookmark.database)")
                                    if look == .preview, bookmark.id == selected {
                                        Text(bookmark.sql).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary)
                                            .padding(SpacingTokens.xs).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: SpacingTokens.xs))
                                            .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xxs)
                                        if let note = bookmark.note {
                                            Label(note, systemImage: "note.text").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                                                .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
                                        }
                                    }
                                }
                                .background(bookmark.id == selected ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xs))
                                .padding(.horizontal, SpacingTokens.xxs)
                                .onTapGesture { selected = bookmark.id }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groups: [(String, [LabRTBookmark])] {
        folders ? ["AML", "Bags", "DBA", "Unfiled"].map { f in (f, LabRTBookmark.samples.filter { $0.folder == f }) }
                : LabRTBookmark.servers.map { s in (s, LabRTBookmark.samples.filter { $0.server == s }) }
    }
}

extension LabRTBookmark {
    static let servers = ["dkloosql10-p", "postgres18"]
}
