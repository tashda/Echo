import SwiftUI
import EchoSense

struct SearchFilterPopoverView: View {
    @Binding var selectedCategories: Set<SearchSidebarCategory>
    let onSelectAll: () -> Void
    let onClearAll: () -> Void

    private func binding(for category: SearchSidebarCategory) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains(category) },
            set: { newValue in
                if newValue {
                    selectedCategories.insert(category)
                } else {
                    selectedCategories.remove(category)
                }
            }
        )
    }

    private var sortedCategories: [SearchSidebarCategory] {
        SearchSidebarCategory.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(TypographyTokens.caption2.weight(.semibold))
                Spacer()
                Button {
                    onSelectAll()
                } label: {
                    Text("Select All")
                        .font(TypographyTokens.detail)
                }
                .buttonStyle(.plain)
                Divider()
                    .frame(height: 14)
                Button {
                    onClearAll()
                } label: {
                    Text("Clear All")
                        .font(TypographyTokens.detail)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(sortedCategories) { category in
#if os(macOS)
                    Toggle(category.displayName, isOn: binding(for: category))
                        .toggleStyle(.checkbox)
                        .font(TypographyTokens.detail)
#else
                    Toggle(category.displayName, isOn: binding(for: category))
                        .font(TypographyTokens.detail)
#endif
                }
            }
        }
    }
}
