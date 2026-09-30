import SwiftUI

/// The rows of the ⌘K palette and the toolbar search card, grouped by section, with the selected
/// row filled like the tree's selection. Hover moves the selection; a click performs the row.
struct CommandPaletteResultsList: View {
    @Bindable var model: CommandPaletteModel
    let onPerform: () -> Void

    @State private var pointerTracker = PointerMoveTracker()

    var body: some View {
        let rows = model.results
        let selected = model.selectedIndex(in: rows)
        if rows.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.none) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                            if index == 0 || rows[index - 1].section != item.section {
                                sectionHeader(item.section)
                            }
                            row(item, isSelected: index == selected)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: LayoutTokens.CommandPalette.listMaxHeight)
                .onChange(of: model.selectedID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: SpacingTokens.xs) {
            if model.isSearchingObjects { ProgressView().controlSize(.small) }
            Text(model.isSearchingObjects ? "Searching" : "No results")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.FloatingSurface.rowHeight, alignment: .leading)
    }

    private func sectionHeader(_ section: CommandPaletteItem.Section) -> some View {
        Text(section.title)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.CommandPalette.sectionHeaderHeight, alignment: .bottomLeading)
    }

    private func row(_ item: CommandPaletteItem, isSelected: Bool) -> some View {
        Button {
            item.perform()
            onPerform()
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: item.systemImage)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.Text.secondary)
                    .frame(width: SpacingTokens.md)
                Text(item.title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: SpacingTokens.none)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.FloatingSurface.rowHeight)
            .background(
                isSelected ? ColorTokens.Sidebar.selectedFill : .clear,
                in: RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(item.id)
        // Only a real mouse move selects: rows scrolling under a still pointer (after an arrow
        // key) mustn't take the selection back.
        .onContinuousHover { phase in
            if case .active = phase, pointerTracker.pointerMoved() { model.select(item.id) }
        }
        .accessibilityLabel([item.title, item.subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
