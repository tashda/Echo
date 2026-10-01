import SwiftUI

struct LabRHAcceptedList: View {
    @State private var search = ""
    private var items: [LabRTHistoryEntry] {
        LabRTHistoryEntry.samples.filter { search.isEmpty || $0.sql.localizedCaseInsensitiveContains(search) || $0.database.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack {
                Text("Query History").font(TypographyTokens.headline)
                Spacer()
                Text("\(items.count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }.padding(SpacingTokens.sm)
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("Search", text: $search, prompt: Text("SQL, server or database")).textFieldStyle(.plain)
            }.font(TypographyTokens.standard).padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            List {
                ForEach(["Today", "Yesterday"], id: \.self) { day in
                    Section(day) {
                        ForEach(items.filter { $0.day == day }) { item in
                            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                                Text(item.sql).font(TypographyTokens.Table.sql).lineLimit(1)
                                Text("\(item.database) · \(item.failed ? "Failed" : item.rows) · \(item.duration) · \(item.time)")
                                    .font(TypographyTokens.detail).foregroundStyle(item.failed ? ColorTokens.Status.error : ColorTokens.Text.secondary).lineLimit(1)
                            }.padding(.vertical, SpacingTokens.xxs).help(item.sql)
                        }
                    }
                }
            }.listStyle(.sidebar).scrollContentBackground(.hidden)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).workspaceCard()
    }
}
