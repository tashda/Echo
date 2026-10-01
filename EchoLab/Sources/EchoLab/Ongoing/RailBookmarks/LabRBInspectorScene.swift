import SwiftUI

struct LabRBInspectorScene: View {
    let look: RailBookmarksRound.ListLook

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabRTRail(symbols: [], selected: nil)
            LabSHCard(server: .production, look: .today, rowLimit: 6)
                .frame(width: 220).frame(maxHeight: .infinity, alignment: .top)
            LabWKEditor().workspaceCard()
            LabRBNativeList(look: look)
                .frame(width: 300).workspaceCard()
        }
        .padding(SpacingTokens.sm).background(ColorTokens.Workspace.canvas)
    }
}

struct LabRBNativeList: View {
    let look: RailBookmarksRound.ListLook
    @State private var selected: String? = "b2"
    @State private var search = ""

    private var items: [LabRTBookmark] {
        LabRTBookmark.samples.filter {
            search.isEmpty || [$0.title, $0.sql, $0.server, $0.database, $0.note ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }
    private var bookmark: LabRTBookmark? { items.first { $0.id == selected } }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack {
                Text("Bookmarks").font(TypographyTokens.headline)
                Spacer()
                Text("\(items.count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }.padding(SpacingTokens.sm)
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("Search", text: $search, prompt: Text("Search bookmarks"))
                    .textFieldStyle(.plain)
            }.font(TypographyTokens.standard).padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            List(selection: $selected) {
                ForEach(["AML", "Bags", "DBA", "Unfiled"], id: \.self) { folder in
                    let group = items.filter { $0.folder == folder }
                    if !group.isEmpty {
                        Section(folder) {
                            ForEach(group) { item in
                                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                    Text(item.title).font(TypographyTokens.standard).lineLimit(1)
                                    Text("\(item.server) · \(item.database)")
                                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                                    if look == .inline, item.id == selected { preview(item) }
                                }.padding(.vertical, SpacingTokens.xxs).tag(item.id)
                            }
                        }
                    }
                }
            }.listStyle(.sidebar).scrollContentBackground(.hidden)
            if look == .detail, let bookmark {
                Divider()
                ScrollView { preview(bookmark).padding(SpacingTokens.sm) }
                    .frame(height: 160)
            }
        }
    }

    private func preview(_ item: LabRTBookmark) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(item.sql).font(TypographyTokens.Table.sql).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let note = item.note {
                Label(note, systemImage: "note.text")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
        }.padding(.top, SpacingTokens.xs)
    }
}
