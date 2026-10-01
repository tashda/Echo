import SwiftUI

/// The server's name with its product under it (round 16). With Section name › Under the
/// server's name, the current section follows the product.
struct LabSDServerRow: View {
    let server: LabSDServer
    let sectionTitle: String?
    let isCollapsed: Bool
    let density: LabSDDensity
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(server.name).font(density.nameFont).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    Text(sectionTitle.map { "\(server.product) · \($0)" } ?? server.product)
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: SpacingTokens.xxs)
                Image(systemName: "chevron.right")
                    .font(SidebarRowConstants.sectionChevronFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .opacity(isHovering || isCollapsed ? 1 : 0)
            }
            .padding(.leading, SpacingTokens.sm)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
            .padding(.top, SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(server.build)
    }
}

/// An S4 Quiet row as Echo draws it after round 16: duotone symbol, counts always in quiet grey,
/// a spinner in the count's place while loading, the selection inset equally on both sides.
struct LabSDNodeRow: View {
    let node: LabSDNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isLoading: Bool
    let density: LabSDDensity
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            icon.frame(width: SidebarRowConstants.iconFrameWidth)
            label
            Spacer(minLength: SpacingTokens.xxxs)
            ZStack(alignment: .trailing) {
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else if node.isFolder {
                    Text("\(node.children.count)").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.quaternary)
                }
            }
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: density.rowSlot - SpacingTokens.micro)
        .background {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(isSelected ? ColorTokens.Sidebar.selectedFill : isHovering ? ColorTokens.Sidebar.hoverFill : .clear)
        }
        .contentShape(Rectangle())
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Open", systemImage: "arrow.up.forward.square") {}
            Button("Refresh", systemImage: "arrow.clockwise") {}
        }
    }

    @ViewBuilder
    private var icon: some View {
        if node.isFolder && isHovering {
            Image(systemName: "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        } else {
            let tint = isSelected ? ColorTokens.accent : node.color.mix(with: ColorTokens.Text.secondary, by: ColorTokens.Explorer.colorfulSoftening)
            ZStack {
                if NSImage(systemSymbolName: "\(node.symbol).fill", accessibilityDescription: nil) != nil {
                    Image(systemName: "\(node.symbol).fill").foregroundStyle(tint.opacity(0.22))
                }
                Image(systemName: node.symbol).foregroundStyle(tint)
            }
            .symbolRenderingMode(.monochrome)
            .font(density.labelFont.weight(.light))
        }
    }

    private var label: some View {
        Group {
            if let prefix = node.prefix {
                Text("\(Text("\(prefix).").foregroundStyle(ColorTokens.Text.tertiary))\(Text(node.title))")
            } else {
                Text(node.title)
            }
        }
        .font(density.labelFont)
        .foregroundStyle(ColorTokens.Text.primary)
        .lineLimit(1)
    }
}

/// Folders first: a spinner where the icon goes and what is loading in grey.
struct LabSDSpinnerRow: View {
    let title: String
    let depth: Int
    let density: LabSDDensity

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            ProgressView().controlSize(.mini).frame(width: SidebarRowConstants.iconFrameWidth)
            Text(title).font(density.labelFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep + SidebarRowConstants.rowLeadingPadding)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
    }
}

/// Section name › Above the rows: the section's name as a small grey heading.
struct LabSDHeadingRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(SidebarRowConstants.sectionHeadingFont)
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, SpacingTokens.sm)
            .padding(.bottom, SpacingTokens.xxs)
    }
}
