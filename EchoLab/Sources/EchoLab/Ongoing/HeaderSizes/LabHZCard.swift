import SwiftUI

/// A card header drawn from `LabHZMetrics` so that every height is the table's height.
struct LabHZCard: View {
    let look: LabHZLook
    let server: LabSHServer
    var rowLimit = 3
    @State private var section = LabHRSection.databases
    @Environment(\.colorScheme) private var scheme

    private var tint: Color { server.color }
    private var banner: LinearGradient { LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom) }
    private var rows: [String] { Array(server.rows.prefix(rowLimit)) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            header
            VStack(spacing: SpacingTokens.none) { ForEach(rows, id: \.self) { LabSHRow(title: $0) } }.padding(.vertical, SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
    }

    @ViewBuilder
    private var header: some View {
        if look.layout == .slim {
            VStack(alignment: .leading, spacing: LabHZMetrics.gap) {
                nameText.padding(.horizontal, SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: LabHZMetrics.slimBanner).background(banner)
                dock(onColour: false).frame(height: LabHZMetrics.dockRow)
            }
        } else {
            content
                .padding(.horizontal, SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: LabHZMetrics.banner(look), alignment: .center)
                .background(banner)
        }
    }

    private var eyebrowText: some View {
        Text(look.eyebrow == .section ? section.title.uppercased() : "SQL SERVER")
            .font(.system(size: LabHZMetrics.eyebrowPoints, weight: .bold)).tracking(1.1)
            .foregroundStyle(ColorTokens.Text.onFill.opacity(0.82)).lineLimit(1)
    }

    private var nameText: some View {
        Text(server.name).font(.system(size: look.size.points, weight: .semibold)).foregroundStyle(ColorTokens.Text.onFill).lineLimit(1)
            .frame(height: LabHZMetrics.nameHeight(look))
    }

    @ViewBuilder
    private var content: some View {
        switch look.layout {
        case .stacked, .compactMenu:
            VStack(alignment: .leading, spacing: LabHZMetrics.gap) {
                if look.eyebrow != .none { eyebrowText.frame(height: LabHZMetrics.eyebrowHeight(look)) }
                nameText
                dock(onColour: true).frame(height: look.layout == .compactMenu ? LabHZMetrics.compactDockRow : LabHZMetrics.dockRow)
            }
        case .inline:
            HStack(spacing: SpacingTokens.xs) {
                nameText
                Spacer(minLength: SpacingTokens.xs)
                dock(onColour: true, compact: true).frame(width: 150, height: LabHZMetrics.dockRow)
            }
        case .twoRows:
            VStack(alignment: .leading, spacing: LabHZMetrics.gap) {
                HStack { nameText; Spacer(minLength: SpacingTokens.xs); if look.eyebrow != .none { eyebrowText } }
                    .frame(height: max(LabHZMetrics.nameHeight(look), LabHZMetrics.eyebrowHeight(look)))
                dock(onColour: true).frame(height: LabHZMetrics.dockRow)
            }
        case .slim:
            EmptyView()
        }
    }

    private func dock(onColour: Bool, compact: Bool = false) -> some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { item in
                Image(systemName: item.symbol)
                    .symbolVariant(item == section ? .fill : .none)
                    .font(.system(size: look.layout == .compactMenu || compact ? 13 : 15, weight: item == section ? .bold : .medium))
                    .foregroundStyle(onColour ? ColorTokens.Text.onFill.opacity(item == section ? 1 : 0.72)
                                              : (item == section ? tint : ColorTokens.Sidebar.symbol))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { section = item }
            }
        }
        .padding(.horizontal, onColour ? SpacingTokens.none : SpacingTokens.xs2)
    }
}

/// The header's height for every name size, with the chosen layout, line and density: the numbers the
/// drawing uses.
struct LabHZTable: View {
    let look: LabHZLook

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Header height in points, from LabHZMetrics (layout \(look.layout.rawValue.prefix(3)), \(look.density.rawValue.prefix(3)))")
                    .font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
                Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xxs) {
                    GridRow {
                        Text("Name size").foregroundStyle(ColorTokens.Text.secondary)
                        ForEach(LabHZEyebrow.allCases, id: \.self) { Text($0.rawValue.components(separatedBy: " · ").last ?? "").foregroundStyle(ColorTokens.Text.secondary) }
                    }
                    ForEach(LabHZSize.allCases, id: \.self) { size in
                        GridRow {
                            Text(size.rawValue.components(separatedBy: " · ").first.map { _ in "\(Int(size.points))pt" } ?? "")
                            ForEach(LabHZEyebrow.allCases, id: \.self) { eyebrow in
                                let value = LabHZMetrics.total(LabHZLook(layout: look.layout, size: size, eyebrow: eyebrow, density: look.density))
                                Text("\(Int(value))").monospacedDigit()
                            }
                        }
                    }
                }
                .font(TypographyTokens.standard)
                Text("None removes the line and its gap: the height drops by \(Int(LabHZMetrics.eyebrowHeight(LabHZLook(layout: look.layout, size: look.size, eyebrow: .section, density: look.density)) + LabHZMetrics.gap))pt in a stacked layout. Nothing else is added under the name.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.md)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}

/// Every size on the chosen layout, line and density, two to a row.
struct LabHZGallery: View {
    let look: LabHZLook
    let server: LabSHServer

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabHZSize.allCases, id: \.self) { size in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text("\(size.rawValue) · \(Int(LabHZMetrics.total(LabHZLook(layout: look.layout, size: size, eyebrow: look.eyebrow, density: look.density))))pt")
                            .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabHZCard(look: LabHZLook(layout: look.layout, size: size, eyebrow: look.eyebrow, density: look.density), server: server, rowLimit: 1)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
