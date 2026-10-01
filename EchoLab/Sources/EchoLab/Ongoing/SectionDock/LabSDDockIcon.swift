import SwiftUI

/// One icon in the dock: grey, the current one in the accent colour with the chosen mark, its
/// name beside it when the round shows it there. Right-click for the section's own menu.
struct LabSDDockIcon: View {
    let section: LabSDSection
    let isCurrent: Bool
    let options: LabSDOptions
    /// M4: smaller icons so every section fits.
    var shrink = 0
    let height: CGFloat
    let onChoose: () -> Void

    @State private var isHovering = false

    private var font: Font {
        options.density.dockIconFont(steps: max(options.size.steps + shrink, -1)).weight(options.weight.weight)
    }

    /// C4 and C6 always put the current icon on a pill.
    private var showsPill: Bool {
        isCurrent && (options.currentMark == .pill || options.capsule == .raisedPill || options.capsule == .glassPill)
    }

    var body: some View {
        Button(action: onChoose) {
            HStack(spacing: SpacingTokens.xxs2) {
                symbol
                if isCurrent && options.sectionName == .inCapsule {
                    Text(section.title)
                        .font(options.density.labelFont.weight(.semibold))
                        .foregroundStyle(ColorTokens.accent)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, showsPill || (isCurrent && options.sectionName == .inCapsule) ? SpacingTokens.xs : SpacingTokens.none)
            .frame(minWidth: height, minHeight: height - SpacingTokens.xxs)
            .background { pill }
            .overlay(alignment: .bottom) { mark }
            .scaleEffect(options.hover == .lift && isHovering && !isCurrent ? 1.12 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(section.title)
        .contextMenu {
            LabSDMenuItems(items: section.menu)
            Divider()
            Menu("Dock") { Button("Customize Dock", systemImage: "slider.horizontal.3") {} }
        }
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var symbol: some View {
        let name = isCurrent && options.currentMark == .filled && NSImage(systemSymbolName: "\(section.symbol).fill", accessibilityDescription: nil) != nil
            ? "\(section.symbol).fill" : section.symbol
        return Image(systemName: name)
            .symbolRenderingMode(.monochrome)
            .font(font)
            .foregroundStyle(isCurrent ? ColorTokens.accent : ColorTokens.Sidebar.symbol)
    }

    @ViewBuilder
    private var pill: some View {
        if showsPill {
            Capsule()
                .fill(options.capsule == .raisedPill ? ColorTokens.Workspace.card : ColorTokens.Sidebar.selectedFill)
                .shadow(color: .black.opacity(options.capsule == .raisedPill ? 0.12 : 0), radius: SpacingTokens.xxxs, y: SpacingTokens.micro)
                .padding(.vertical, SpacingTokens.xxxs)
        } else if options.hover == .fill && isHovering && !isCurrent {
            Circle().fill(ColorTokens.Sidebar.hoverFill).padding(SpacingTokens.xxxs)
        }
    }

    @ViewBuilder
    private var mark: some View {
        if isCurrent && options.capsule == .underline {
            Capsule().fill(ColorTokens.accent).frame(width: SpacingTokens.sm, height: SpacingTokens.xxxs).offset(y: SpacingTokens.xxs)
        } else if isCurrent && options.currentMark == .dot {
            Circle().fill(ColorTokens.accent).frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs).offset(y: SpacingTokens.xxxs)
        }
    }
}
