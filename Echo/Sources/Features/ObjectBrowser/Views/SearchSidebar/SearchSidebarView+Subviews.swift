import SwiftUI

extension SearchSidebarView {
    var isSearchFieldDisabled: Bool {
        guard viewModel.selectedCategories.contains(where: { $0 != .queryTabs }) else { return false }
        guard let session = activeSession else { return true }
        return session.selectedDatabaseName?.isEmpty != false
    }

    var isFilterActive: Bool {
        viewModel.selectedCategories.count != SearchSidebarCategory.allCases.count
    }

    var searchBar: some View {
        SidebarSearchBar(
            placeholder: "Search tables, views, query tabs...",
            text: $viewModel.query,
            isDisabled: isSearchFieldDisabled,
            showsClearButton: !viewModel.query.isEmpty,
            onClear: { viewModel.clearQuery() },
            focusBinding: $isSearchFieldFocused,
            clearShortcut: .cancelAction
        ) {
            filterButton
        }
    }

    var filterButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(TypographyTokens.display.weight(.semibold))
                .foregroundStyle(
                    isFilterActive
                        ? ColorTokens.accent
                        : ColorTokens.Text.secondary.opacity(0.6)
                )
                .padding(SpacingTokens.xxxs)
                .background(
                    Circle()
                        .fill(ColorTokens.accent.opacity(isFilterActive ? 0.18 : 0))
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(filterLabel)
        .accessibilityLabel(filterLabel)
        .popover(isPresented: $isFilterPopoverPresented, arrowEdge: .top) {
            SearchFilterPopoverView(
                selectedCategories: $viewModel.selectedCategories,
                onSelectAll: {
                    viewModel.resetFilters()
                },
                onClearAll: {
                    viewModel.selectedCategories.removeAll()
                }
            )
            .padding(SpacingTokens.sm2)
            .frame(minWidth: 220)
        }
    }

    private var filterLabel: String {
        let total = SearchSidebarCategory.allCases.count
        let selected = viewModel.selectedCategories.count

        if selected == 0 {
            return "No Filters"
        }
        if selected == total {
            return "All Objects"
        }
        if selected == 1, let first = viewModel.selectedCategories.first {
            return first.displayName
        }
        return "\(selected) Filters"
    }
}
