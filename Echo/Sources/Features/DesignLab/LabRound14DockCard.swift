#if DEBUG
import SwiftUI

/// One section's tree. Each section keeps its own scroll view and expansion state alive, so
/// switching sections and coming back returns you exactly where you were.
struct LabRound14DockSectionList: View {
    let section: LabDockSection
    let iconMode: LabDockIconMode
    let animation: Animation

    @State private var expanded: Set<String>
    @State private var selectedID: String?

    init(section: LabDockSection, iconMode: LabDockIconMode, animation: Animation) {
        self.section = section
        self.iconMode = iconMode
        self.animation = animation
        _expanded = State(initialValue: section.initiallyExpanded)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.micro) {
                ForEach(flattened, id: \.node.id) { item in
                    LabRound14DockRow(
                        node: item.node, depth: item.depth, isExpanded: expanded.contains(item.node.id),
                        isSelected: selectedID == item.node.id, iconMode: iconMode
                    ) {
                        withAnimation(animation) {
                            selectedID = item.node.id
                            if item.node.isFolder {
                                if expanded.contains(item.node.id) { expanded.remove(item.node.id) } else { expanded.insert(item.node.id) }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, SpacingTokens.xxs)
        }
        .scrollIndicators(.never)
    }

    private var flattened: [(node: LabDockNode, depth: Int)] {
        var rows: [(LabDockNode, Int)] = []
        func walk(_ nodes: [LabDockNode], depth: Int) {
            for node in nodes {
                rows.append((node, depth))
                if node.isFolder, expanded.contains(node.id) { walk(node.children, depth: depth + 1) }
            }
        }
        walk(section.nodes, depth: 0)
        return rows
    }
}

/// TC1: the server card with the section dock pinned at the top. Rows scroll under the dock,
/// which the system blurs with its scroll edge effect.
struct LabRound14DockCard: View {
    let iconMode: LabDockIconMode
    let labels: LabDockLabels
    let edge: LabDockEdge
    let animation: Animation

    @State private var current: LabDockSection = .databases
    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    var body: some View {
        LabCard(cornerRadius: cardCornerRadius) {
            ZStack(alignment: .topLeading) {
                ForEach(LabDockSection.allCases) { section in
                    LabRound14DockSectionList(section: section, iconMode: iconMode, animation: animation)
                        .opacity(section == current ? 1 : 0)
                        .offset(x: section == current ? 0 : SpacingTokens.xs)
                        .allowsHitTesting(section == current)
                        .accessibilityHidden(section != current)
                }
            }
            .safeAreaBar(edge: .top) { header }
            .scrollEdgeEffectStyle(edge.style, for: .top)
        }
        .frame(width: LayoutTokens.DesignLabRound14.dockCardWidth, height: LayoutTokens.DesignLabRound14.dockCardHeight)
        .clipShape(.rect(cornerRadius: cardCornerRadius))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Test MSSQL").font(SidebarRowConstants.serverHeaderFont)
                Spacer()
                Text("SQL Server 16.0.4250.1").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            HStack(spacing: SpacingTokens.xxxs) {
                ForEach(LabDockSection.allCases) { section in dockButton(section) }
            }
            .padding(.horizontal, SpacingTokens.xxs2)
        }
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs2)
    }

    private func dockButton(_ section: LabDockSection) -> some View {
        let isCurrent = section == current
        return Button {
            withAnimation(animation) { current = section }
        } label: {
            HStack(spacing: SpacingTokens.xxs2) {
                LabDuotoneSymbol(name: section.symbol, color: section.color, mode: iconMode,
                                 monoColor: isCurrent ? ColorTokens.accent : ColorTokens.Sidebar.symbol,
                                 font: TypographyTokens.prominent)
                if labels == .currentTitle && isCurrent {
                    Text(section.rawValue)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(minWidth: LayoutTokens.DesignLabRound14.dockButtonSize, minHeight: LayoutTokens.DesignLabRound14.dockButtonSize)
            .frame(maxWidth: labels == .iconsOnly ? .infinity : nil)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: LayoutTokens.DesignLabRound14.dockButtonCornerRadius, style: .continuous)
                        .fill(ColorTokens.Sidebar.selectedFill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(section.rawValue)
        .accessibilityLabel(section.rawValue)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
#endif
