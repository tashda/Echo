import SwiftUI

/// Round 43.5 (SE2): matching settings across every page, each with the page it lives on.
struct SettingsSearchResults: View {
    let query: String
    let open: (SettingsSearchEntry) -> Void

    var body: some View {
        let matches = SettingsSearchIndex.matches(for: query)
        if matches.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(matches) { entry in
                Button { open(entry) } label: {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(entry.title).font(TypographyTokens.standard)
                        Text(entry.location).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
