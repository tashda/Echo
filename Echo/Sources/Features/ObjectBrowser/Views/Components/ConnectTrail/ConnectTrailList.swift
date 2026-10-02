import SwiftUI

/// The opened trail's list (round 52, CT1 and KB1): a search field with the focus, then the saved
/// connections under their folder's heading. Return connects the highlighted row (the first match
/// until an arrow key or the pointer picks another); Escape closes the trail.
struct ConnectTrailList: View {
    let entries: [ConnectTrailEntry]
    let markColor: (UUID) -> Color
    let onConnect: (UUID) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var highlightedID: UUID?
    @FocusState private var isSearching: Bool

    private var sections: [ConnectTrailSection] { ConnectTrailListing.sections(entries, query: query) }
    private var orderedIDs: [UUID] { ConnectTrailListing.orderedIDs(sections) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            searchField
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(sections) { section in
                            heading(section.title)
                            ForEach(section.entries) { entry in
                                ConnectTrailRow(
                                    entry: entry,
                                    color: markColor(entry.id),
                                    isHighlighted: entry.id == highlightedID,
                                    onHover: { highlightedID = entry.id },
                                    action: { onConnect(entry.id) }
                                )
                                .id(entry.id)
                            }
                        }
                        emptyMessage
                    }
                    .padding(.horizontal, SpacingTokens.xxs1)
                    .padding(.vertical, SpacingTokens.xxs)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .onChange(of: highlightedID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
        .task { isSearching = true }
        .onAppear { highlightedID = ConnectTrailListing.highlight(current: nil, in: orderedIDs) }
        .onChange(of: query) { _, _ in
            highlightedID = ConnectTrailListing.highlight(current: nil, in: orderedIDs)
        }
        .onKeyPress(.downArrow) { moveHighlight(by: 1) }
        .onKeyPress(.upArrow) { moveHighlight(by: -1) }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private func moveHighlight(by step: Int) -> KeyPress.Result {
        highlightedID = ConnectTrailListing.moved(from: highlightedID, in: orderedIDs, by: step)
        return .handled
    }

    private var searchField: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
            TextField("", text: $query, prompt: Text("Search connections"))
                .textFieldStyle(.plain)
                .font(TypographyTokens.standard)
                .focused($isSearching)
                .onSubmit {
                    if let id = ConnectTrailListing.highlight(current: highlightedID, in: orderedIDs) { onConnect(id) }
                }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
        .padding(SpacingTokens.xs)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(SidebarRowConstants.sectionHeadingFont)
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.top, SpacingTokens.xs)
            .padding(.bottom, SpacingTokens.xxs)
    }

    @ViewBuilder
    private var emptyMessage: some View {
        if sections.isEmpty {
            Text(entries.isEmpty ? "No saved connections" : "No connection matches \"\(query)\"")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .padding(SpacingTokens.sm)
        }
    }
}
