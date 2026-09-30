import SwiftUI

struct LabRound13TabBar: View {
    let design: LabNewTabDesign
    @Binding var tabs: [LabTabItem]
    @Binding var activeID: UUID?

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(tabs) { tab in
                LabRound13TabButton(
                    design: design,
                    tab: tab,
                    isActive: tab.id == activeID,
                    onSelect: { activeID = tab.id },
                    onClose: { close(tab) }
                )
            }
            addButton
        }
        .padding(design == .tonal ? SpacingTokens.xxs : SpacingTokens.none)
        .frame(height: LayoutTokens.TabProposals.barHeight)
        .background {
            if design == .tonal {
                RoundedRectangle(cornerRadius: LayoutTokens.TabProposals.tabCornerRadius)
                    .fill(ColorTokens.TabStrip.Proposals.track)
            }
        }
    }

    private var addButton: some View {
        Button {
            let tab = LabTabItem(title: "Query \(tabs.count + 1)", database: "employees", symbol: "tablecells", serverColor: .blue)
            tabs.append(tab)
            activeID = tab.id
        } label: {
            Image(systemName: "plus")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: LayoutTokens.TabProposals.addButtonWidth, height: LayoutTokens.TabProposals.tabHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New Query Tab")
        .accessibilityLabel("New Query Tab")
    }

    private func close(_ tab: LabTabItem) {
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        activeID = LabRound13TabSelection.activeID(
            afterClosing: tab.id,
            previousActiveID: activeID,
            closedIndex: index,
            remainingIDs: tabs.map(\.id)
        )
    }
}

private struct LabRound13TabButton: View {
    let design: LabNewTabDesign
    let tab: LabTabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Button(action: onSelect) {
                HStack(spacing: SpacingTokens.xxs2) {
                    if tab.isRunning {
                        ProgressView().controlSize(.mini)
                            .frame(width: LayoutTokens.TabProposals.tabIconWidth)
                    } else {
                        Image(systemName: tab.symbol)
                            .frame(width: LayoutTokens.TabProposals.tabIconWidth)
                    }
                    Text(tab.title)
                        .lineLimit(1)
                    Spacer(minLength: SpacingTokens.none)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(tab.title) · \(tab.database)\(tab.isRunning ? " · Running" : "")")
            .accessibilityLabel("\(tab.title), \(tab.database)")
            .accessibilityValue(isActive ? "Selected" : "")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .accessibilityLabel("Close \(tab.title)")
            .help("Close \(tab.title)")
        }
        .font(TypographyTokens.detail.weight(isActive ? .semibold : .regular))
        .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.xs)
        .frame(maxWidth: .infinity)
        .frame(height: LayoutTokens.TabProposals.tabHeight)
        .background { tabBackground }
        .overlay(alignment: .bottom) {
            if design == .quiet && isActive {
                Capsule()
                    .fill(ColorTokens.accent)
                    .frame(width: SpacingTokens.lg, height: LayoutTokens.TabProposals.activeRuleHeight)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var tabBackground: some View {
        switch design {
        case .tonal:
            RoundedRectangle(cornerRadius: LayoutTokens.TabProposals.tabCornerRadius)
                .fill(isActive ? ColorTokens.TabStrip.Proposals.selected : isHovering ? ColorTokens.TabStrip.Proposals.inactive : .clear)
        case .attached:
            UnevenRoundedRectangle(
                topLeadingRadius: LayoutTokens.TabProposals.tabCornerRadius,
                topTrailingRadius: LayoutTokens.TabProposals.tabCornerRadius
            )
            .fill(isActive ? ColorTokens.Workspace.card : ColorTokens.TabStrip.Proposals.inactive)
        case .quiet:
            RoundedRectangle(cornerRadius: LayoutTokens.TabProposals.tabCornerRadius)
                .fill(isActive ? ColorTokens.TabStrip.Proposals.inactive : isHovering ? ColorTokens.Surface.hover : .clear)
        }
    }
}
