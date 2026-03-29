import SwiftUI

/// Isolated view struct that owns the `@FocusState` for the search field.
/// Extracting this into its own view prevents content-area structural identity
/// changes (e.g. switching from placeholder to results) from destroying focus.
struct SearchSidebarSearchBar: View {
    @Bindable var viewModel: SearchSidebarViewModel
    @Binding var isFilterPopoverPresented: Bool
    @FocusState private var isFieldFocused: Bool

    private var isFilterActive: Bool {
        viewModel.selectedCategories.count != SearchSidebarCategory.allCases.count
    }

    private var isScopeActive: Bool {
        viewModel.scope != .allServers
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)

            TextField("Search all connections…", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(TypographyTokens.standard)
                .focused($isFieldFocused)

            if !viewModel.query.isEmpty {
                Button { viewModel.clearQuery() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            if viewModel.hasSessions {
                scopeButton
            }

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(width: 1, height: 16)

            filterButton
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .frame(height: WorkspaceChromeMetrics.chromeBackgroundHeight)
        .background(
            RoundedRectangle(cornerRadius: WorkspaceChromeMetrics.chromeBackgroundHeight / 2, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkspaceChromeMetrics.chromeBackgroundHeight / 2, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, SpacingTokens.xxs2)
        .padding(.top, SpacingTokens.xs)
        .padding(.bottom, SpacingTokens.xxs2)
        .onReceive(NotificationCenter.default.publisher(for: .activateSidebarSearch)) { _ in
            isFieldFocused = true
        }
    }

    // MARK: - Scope Button

    private var scopeButton: some View {
        ScopeMenuButton(
            isScopeActive: isScopeActive,
            scope: viewModel.scope,
            servers: viewModel.availableServers,
            databases: viewModel.availableDatabases,
            scopedSessionID: viewModel.scopedSessionID,
            scopedDatabaseName: viewModel.scopedDatabaseName,
            onScopeChange: { viewModel.scope = $0 }
        )
        .help(scopeLabel)
    }

    private var scopeLabel: String {
        if let id = viewModel.scopedSessionID,
           let server = viewModel.availableServers.first(where: { $0.id == id }) {
            if let db = viewModel.scopedDatabaseName {
                return "\(server.name) › \(db)"
            }
            return server.name
        }
        return "All Servers"
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            Image(systemName: isFilterActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(
                    isFilterActive ? ColorTokens.accent : ColorTokens.Text.secondary
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(filterLabel)
        .accessibilityLabel(filterLabel)
        .popover(isPresented: $isFilterPopoverPresented, arrowEdge: .top) {
            SearchFilterPopoverView(
                selectedCategories: $viewModel.selectedCategories,
                onSelectAll: { viewModel.resetFilters() },
                onClearAll: { viewModel.selectedCategories.removeAll() }
            )
            .padding(SpacingTokens.sm2)
            .frame(minWidth: 220)
        }
    }

    private var filterLabel: String {
        let total = SearchSidebarCategory.allCases.count
        let selected = viewModel.selectedCategories.count

        if selected == 0 { return "No Filters" }
        if selected == total { return "All Objects" }
        if selected == 1, let first = viewModel.selectedCategories.first {
            return first.displayName
        }
        return "\(selected) Filters"
    }
}
