import SwiftUI

/// The dock row: one icon button per section, the chosen one on the grey selection fill.
/// Icons follow the Duotone / Mono setting; titles and counts are in the tooltips.
struct ExplorerDockRow: View {
    let items: [ExplorerDockItem]
    let selectedID: String
    let iconColor: (Color) -> Color
    let onSelect: (String) -> Void

    @Environment(\.sidebarUsesDuotoneIcons) private var usesDuotone

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(items) { item in
                button(item)
            }
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .frame(maxHeight: .infinity)
    }

    private func button(_ item: ExplorerDockItem) -> some View {
        let isSelected = item.id == selectedID
        let color = usesDuotone ? iconColor(item.color) : (isSelected ? ColorTokens.accent : ColorTokens.Sidebar.symbol)
        return Button { onSelect(item.id) } label: {
            ZStack {
                if usesDuotone, let fill = SidebarDuotoneSymbols.fillName(for: item.symbol) {
                    Image(systemName: fill).foregroundStyle(color.opacity(SidebarDuotoneSymbols.fillOpacity))
                }
                Image(systemName: item.symbol).foregroundStyle(color)
            }
            .symbolRenderingMode(.monochrome)
            .font(TypographyTokens.prominent)
            .frame(maxWidth: .infinity)
            .frame(height: LayoutTokens.ExplorerDock.buttonHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: LayoutTokens.ExplorerDock.buttonCornerRadius, style: .continuous)
                        .fill(ColorTokens.Sidebar.selectedFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.count.map { "\(item.title) · \($0)" } ?? item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
