import SwiftUI

/// The connect drawer's content (round 56, CD1; round 52, CT1 and KB1): a search field with the
/// focus and New Connection, Manage Connections, Quick Connect and × beside it, then the saved
/// connections under their folder's heading. Return connects the highlighted row (the first match
/// until an arrow key or the pointer picks another); Escape closes the drawer.
struct ConnectTrailList: View {
    let entries: [ConnectTrailEntry]
    let markColor: (UUID) -> Color
    let onConnect: (UUID) -> Void
    let onNewConnection: () -> Void
    let onManageConnections: () -> Void
    let onQuickConnect: () -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var highlightedID: UUID?
    @FocusState private var isSearching: Bool
    /// The user clicked into the search: the field takes the row and the icon buttons step aside.
    /// The focus the drawer takes on opening does not count; the row stays compact until a click
    /// or typing.
    @State private var hasClickedSearch = false
    @State private var isAutoFocusing = false
    @Environment(\.echoMotion) private var motion

    private var isSearchExpanded: Bool { hasClickedSearch || !query.isEmpty }

    private var sections: [ConnectTrailSection] { ConnectTrailListing.sections(entries, query: query) }
    private var orderedIDs: [UUID] { ConnectTrailListing.orderedIDs(sections) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            header
            connectionList
        }
        .task {
            isAutoFocusing = true
            isSearching = true
        }
        .onChange(of: isSearching) { _, focused in
            if focused {
                if isAutoFocusing { isAutoFocusing = false } else { hasClickedSearch = true }
            } else {
                hasClickedSearch = false
            }
        }
        .onAppear { highlightedID = ConnectTrailListing.highlight(current: nil, in: orderedIDs) }
        .onChange(of: query) { _, _ in
            highlightedID = ConnectTrailListing.highlight(current: nil, in: orderedIDs)
        }
        .onKeyPress(.downArrow) { moveHighlight(by: 1) }
        .onKeyPress(.upArrow) { moveHighlight(by: -1) }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    /// A short result set should leave no blank glass below its last row. When the rows would
    /// exceed the rail, keep the drawer within that space and restore the scrolling list.
    @ViewBuilder
    private var connectionList: some View {
        ViewThatFits(in: .vertical) {
            connectionRows
                .fixedSize(horizontal: false, vertical: true)

            scrollingConnectionRows
        }
    }

    private var scrollingConnectionRows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                connectionRows
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
            .onChange(of: highlightedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var connectionRows: some View {
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

    private func moveHighlight(by step: Int) -> KeyPress.Result {
        highlightedID = ConnectTrailListing.moved(from: highlightedID, in: orderedIDs, by: step)
        return .handled
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            searchField
                .frame(maxWidth: .infinity)
            if !isSearchExpanded {
                actionButtons
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(SpacingTokens.xs)
        .animation(motion.standard, value: isSearchExpanded)
    }

    private var actionButtons: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ConnectTrailIconButton(symbol: "plus", title: "New Connection", action: onNewConnection)
            ConnectTrailIconButton(symbol: "gearshape", title: "Manage Connections", action: onManageConnections)
            ConnectTrailIconButton(symbol: "bolt.fill", title: "Quick Connect", action: onQuickConnect)
            ConnectTrailIconButton(
                symbol: "xmark",
                title: "Close",
                font: TypographyTokens.detail.weight(.semibold),
                action: onClose
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
            TextField("", text: $query, prompt: Text(isSearchExpanded ? "Search connections" : "Search"))
                .textFieldStyle(.plain)
                .font(TypographyTokens.standard)
                .focused($isSearching)
                .onSubmit {
                    if let id = ConnectTrailListing.highlight(current: highlightedID, in: orderedIDs) { onConnect(id) }
                }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: ConnectTrailIconButton.size)
        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { hasClickedSearch = true; isSearching = true }
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
