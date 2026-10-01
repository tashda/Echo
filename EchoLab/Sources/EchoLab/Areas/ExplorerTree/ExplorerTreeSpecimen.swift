import SwiftUI

/// The Explorer tree's server card as Echo draws it today: the server's name, the glass dock,
/// and quiet rows. Each part carries its Spec number. It is self-contained (a snapshot), so the
/// server card round can keep changing without moving this page.
struct ExplorerTreeSpecimen: View {
    let settings: ExplorerTreeSpecimenSettings
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius
    @State private var isHeaderHovering = false

    private static let dock: [(symbol: String, color: Color)] = [
        ("cylinder", ColorTokens.Explorer.databaseInstance), ("shield", ColorTokens.Explorer.security),
        ("clock", ColorTokens.Explorer.jobs), ("gearshape", ColorTokens.Text.secondary),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            card
            card2
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// The card as it rests: name, dock, rows.
    private var card: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                header
                dock
            }
            // Round 30.1, HD4: the server's colour washes down from the top through the dock.
            .background {
                LinearGradient(colors: [ColorTokens.Status.info.opacity(0.2), ColorTokens.Status.info.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous))
                    .specAnchor("2.6")
            }
            rows
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 360)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .shadow(ShadowTokens.workspaceCard)
        .specAnchor("1.1")
    }

    /// A second, shorter card: every server has its own.
    private var card2: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Reporting PG").font(SidebarRowConstants.serverHeaderFont)
            Text("PostgreSQL 16.2").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .frame(width: 180, height: 120, alignment: .topLeading)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .shadow(ShadowTokens.workspaceCard)
        .specAnchor("1.2")
    }

    /// The open card's header: the chevron, turned down, centred on the two lines and shown on
    /// hover (round 30.2).
    private var header: some View {
        HStack(alignment: .center, spacing: SidebarRowConstants.iconTextSpacing) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text("Test MSSQL").font(SidebarRowConstants.serverHeaderFont).lineLimit(1).specAnchor("2.1")
                Text("SQL Server 2022 · Databases").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1).specAnchor("2.2")
            }
            Spacer(minLength: SpacingTokens.xxs)
            Image(systemName: "chevron.right")
                .font(SidebarRowConstants.sectionChevronFont)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(90))
                .frame(width: SidebarRowConstants.chevronWidth)
                .opacity(isHeaderHovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHeaderHovering)
                .specAnchor("2.4")
        }
        .contentShape(Rectangle())
        .onHover { isHeaderHovering = $0 }
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.leading, SpacingTokens.sm)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs2)
    }

    private var dock: some View {
        GlassEffectContainer {
            HStack(spacing: SpacingTokens.none) {
                ForEach(Array(Self.dock.enumerated()), id: \.offset) { index, item in
                    let isCurrent = index == 0
                    // The current icon in the header's colour (round 30.1, DK1).
                    LabDuotoneSymbol(name: item.symbol, color: isCurrent ? ColorTokens.Status.info : item.color, mode: settings.dockMode,
                                     monoColor: isCurrent ? ColorTokens.Status.info : ColorTokens.Sidebar.symbol, font: TypographyTokens.prominent.weight(.medium))
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .specAnchor(isCurrent ? "3.2" : "3.3")
                }
                Image(systemName: "chevron.right.2")
                    .font(TypographyTokens.prominent.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(minWidth: 28, minHeight: 28)
                    .specAnchor("3.4")
            }
            .padding(.horizontal, SpacingTokens.xxs2)
            .frame(height: 28)
            .glassEffect(.regular, in: .capsule)
            .overlay(Capsule().strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.8), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
            .shadow(color: .black.opacity(0.08), radius: SpacingTokens.xxs, y: SpacingTokens.micro)
            .specAnchor("3.1")
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.bottom, SpacingTokens.xxs)
    }

    private var rows: some View {
        let forced = settings.forced
        return VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            ExplorerSpecRow(title: "AdventureWorks2022", symbol: "cylinder", color: ColorTokens.Explorer.databaseInstance, depth: 0,
                            isFolder: true, isExpanded: true, count: 4, iconMode: settings.iconMode)
            ExplorerSpecRow(title: "Tables", symbol: "folder", color: ColorTokens.Explorer.tables, depth: 1,
                            isFolder: true, isExpanded: true, count: 21, iconMode: settings.iconMode, forcedHover: forced == "hoverRow")
                .specAnchor("4.4")
            ExplorerSpecRow(title: "Department", prefix: "HumanResources", symbol: "tablecells", color: ColorTokens.Sidebar.symbol, depth: 2,
                            iconMode: settings.iconMode).specAnchor("4.3")
            ExplorerSpecRow(title: "Employee", prefix: "HumanResources", symbol: "tablecells", color: ColorTokens.Sidebar.symbol, depth: 2,
                            isSelected: true, iconMode: settings.iconMode).specAnchor("4.7")
            ExplorerSpecRow(title: "Address", prefix: "Person", symbol: "tablecells", color: ColorTokens.Sidebar.symbol, depth: 2,
                            iconMode: settings.iconMode, forcedHover: forced == "hoverObject").specAnchor("4.6")
            ExplorerSpecRow(title: "Views", symbol: "folder", color: ColorTokens.Explorer.views, depth: 1,
                            isFolder: true, isExpanded: false, count: 4, iconMode: settings.iconMode).specAnchor("4.5")
        }
        .specAnchor("4.1")
    }
}

/// One row as `SidebarRow` draws it, with the fill states forced for the Spec page.
private struct ExplorerSpecRow: View {
    let title: String
    var prefix: String?
    let symbol: String
    let color: Color
    let depth: Int
    var isFolder = false
    var isExpanded = false
    var isSelected = false
    var count: Int?
    let iconMode: LabDockIconMode
    var forcedHover = false

    @State private var isHovering = false
    private var hovering: Bool { isHovering || forcedHover }

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            icon.frame(width: SidebarRowConstants.iconFrameWidth, height: SidebarRowConstants.iconFrameHeight)
            label
            Spacer(minLength: SpacingTokens.xxxs)
            if let count { Text("\(count)").font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.quaternary) }
        }
        .padding(.leading, SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SpacingTokens.xxs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(isSelected ? ColorTokens.Sidebar.selectedFill : hovering ? ColorTokens.Sidebar.hoverFill : .clear)
        }
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    @ViewBuilder private var icon: some View {
        if isFolder && hovering {
            Image(systemName: "chevron.right").font(SidebarRowConstants.chevronFont).foregroundStyle(ColorTokens.Text.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        } else {
            LabDuotoneSymbol(name: symbol, color: isSelected ? ColorTokens.accent : color.mix(with: ColorTokens.Text.secondary, by: ColorTokens.Explorer.colorfulSoftening), mode: iconMode,
                             monoColor: isSelected ? ColorTokens.accent : ColorTokens.Sidebar.symbol)
        }
    }

    private var label: some View {
        Group {
            if let prefix { Text("\(Text("\(prefix).").foregroundStyle(ColorTokens.Text.tertiary))\(Text(title))") } else { Text(title) }
        }
        .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
    }
}
