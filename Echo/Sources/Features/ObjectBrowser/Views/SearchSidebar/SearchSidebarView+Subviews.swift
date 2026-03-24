import SwiftUI

extension SearchSidebarView {

    var isFilterActive: Bool {
        viewModel.selectedCategories.count != SearchSidebarCategory.allCases.count
    }

    var searchBar: some View {
        VStack(spacing: SpacingTokens.xxs2) {
            SidebarSearchBar(
                placeholder: "Search all connections...",
                text: $viewModel.query,
                isDisabled: false,
                showsClearButton: !viewModel.query.isEmpty,
                onClear: { viewModel.clearQuery() },
                focusBinding: $isSearchFieldFocused,
                clearShortcut: .cancelAction
            ) {
                filterButton
            }

            if viewModel.availableServers.count > 1 {
                scopePicker
            }
        }
    }

    var scopePicker: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Picker("Scope", selection: $viewModel.scope) {
                Text("All Servers")
                    .tag(SearchScope.allServers)

                ForEach(viewModel.availableServers, id: \.id) { server in
                    Text(server.name)
                        .tag(SearchScope.server(connectionSessionID: server.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs2)
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
