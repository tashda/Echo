import SwiftUI

/// One tree row drawn in a given style. Everything it shows comes from the row, the spec and the
/// page's look, so the same row reads differently in each style.
struct LabTreeCardRow: View {
    let row: LabFlatRow
    let spec: LabTreeSpec
    let look: LabTreeLook
    let serverColor: Color
    let isExpanded: Bool
    let isSelected: Bool
    let isOnPath: Bool
    /// The guide column that turns accent: the one owned by the selected row's parent.
    let accentGuideOwner: String?
    let onTap: () -> Void

    @State private var isHovering = false

    private var role: LabNodeRole { row.node.role }
    private var isTwoLine: Bool { spec.showsMetrics && role == .database && row.node.metric != nil }
    private var height: CGFloat { spec.rowHeight + (isTwoLine ? 14 : 0) }
    private var onSolid: Bool { isSelected && spec.selection == .accentSolid }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: CGFloat(row.depth) * spec.indent)
            HStack(spacing: spec.iconGap) {
                if case .leading = spec.chevron { chevron.frame(width: spec.chevronWidth) }
                iconSlot.frame(width: spec.iconFrame)
                label
                Spacer(minLength: 4)
                trailing
            }
            .padding(.leading, spec.innerPadding)
            .padding(.trailing, 8)
            .frame(height: height)
            .background { highlight }
        }
        .padding(.horizontal, spec.outerPadding)
        .background(alignment: .topLeading) { guides }
        .padding(.bottom, spec.rowGap)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
    }

    // MARK: Chevron and icon

    @ViewBuilder
    private var chevron: some View {
        if row.isContainer {
            let (size, weight, strength): (CGFloat, Font.Weight, LabTreeSpec.Strength) = switch spec.chevron {
            case .leading(let size, let weight, let strength): (size, weight, strength)
            case .replacesIcon: (10, .semibold, .tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: size, weight: weight))
                .foregroundStyle(onSolid ? AnyShapeStyle(.white.opacity(0.8)) : strength == .tertiary ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }

    @ViewBuilder
    private var iconSlot: some View {
        if case .replacesIcon = spec.chevron, row.isContainer, isHovering {
            chevron
        } else if spec.icon == .tiles, row.isContainer {
            tile
        } else if !row.node.resolvedSymbol.isEmpty {
            symbol
        }
    }

    private var symbolName: String {
        let base = row.node.resolvedSymbol
        let wantsFill = spec.icon == .filled || spec.icon == .gradient
        return wantsFill && LabNodeRole.fillable.contains(base) ? base + ".fill" : base
    }

    private var symbol: some View {
        Image(systemName: symbolName)
            .font(.system(size: spec.iconSize, weight: spec.icon == .light ? .light : .regular))
            .symbolRenderingMode(spec.icon == .outline || spec.icon == .light || spec.icon == .gradient ? .monochrome : .hierarchical)
            .symbolColorRenderingMode(spec.icon == .gradient ? .gradient : nil)
            .foregroundStyle(iconColor)
    }

    private var tile: some View {
        let base = row.node.resolvedSymbol
        let glyph = LabNodeRole.fillable.contains(base) ? base + ".fill" : base
        let colorful = look.icons == .colorful
        let accentOpen = !colorful && isExpanded
        let fill: AnyShapeStyle = colorful ? AnyShapeStyle(tileColor.gradient) : accentOpen ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.primary.opacity(0.08))
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(fill)
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: glyph)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colorful || accentOpen ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
    }

    private var tileColor: Color {
        look.palette.color(for: role, serverColor: serverColor)
    }

    private var iconColor: Color {
        if isSelected { return onSolid ? .white : .accentColor }
        if spec.highlightsPath && isOnPath { return .accentColor }
        let isKey = role == .keyColumn || role == .foreignKeyColumn
        switch look.icons {
        case .monochrome:
            // The decided default: grey, with the accent on open folders so you see your path.
            if isExpanded && row.isContainer && !spec.highlightsPath { return .accentColor }
            return ColorTokens.Text.secondary
        case .colorful:
            return row.isContainer || isKey ? tileColor : ColorTokens.Text.secondary
        }
    }

    // MARK: Label and trailing

    @ViewBuilder
    private var label: some View {
        if isTwoLine, let metric = row.node.metric {
            VStack(alignment: .leading, spacing: 1) {
                title
                Text(metric).font(.system(size: 11)).foregroundStyle(onSolid ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
        } else {
            title
        }
    }

    private var title: some View {
        let weight: Font.Weight = spec.highlightsPath && isOnPath ? .medium : .regular
        let name = Text(row.node.title).foregroundStyle(onSolid ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        let text: Text = if row.schemaDisplay == .prefix, let schema = row.node.schema {
            Text("\(Text(schema + ".").foregroundStyle(onSolid ? AnyShapeStyle(.white.opacity(0.7)) : AnyShapeStyle(.tertiary)))\(name)")
        } else {
            name
        }
        return text.font(.system(size: spec.labelSize, weight: weight)).lineLimit(1)
    }

    @ViewBuilder
    private var trailing: some View {
        if let count = row.node.count, count > 0 {
            countView(count)
        } else if row.schemaDisplay == .trailing, let schema = row.node.schema {
            detailText(schema)
        } else if spec.showsMetrics, role != .database, let metric = row.node.metric {
            detailText(metric)
        } else if let detail = row.node.detail {
            detailText(detail)
        }
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(onSolid ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
            .lineLimit(1)
    }

    @ViewBuilder
    private func countView(_ count: Int) -> some View {
        switch spec.count {
        case .plain:
            detailText("\(count)")
        case .onHover:
            detailText("\(count)").opacity(isHovering ? 1 : 0)
        case .capsule:
            Text("\(count)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
    }

    // MARK: Highlight and guides

    @ViewBuilder
    private var highlight: some View {
        let shape = RoundedRectangle(cornerRadius: spec.corner, style: .continuous)
        if isSelected {
            switch spec.selection {
            case .grey: shape.fill(ColorTokens.Sidebar.selectedFill)
            case .accentTint: shape.fill(Color.accentColor.opacity(0.18))
            case .accentSolid: shape.fill(Color.accentColor)
            case .accentBar:
                shape.fill(Color.accentColor.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.accentColor).frame(width: 3).padding(.vertical, 5).padding(.leading, 2)
                    }
            }
        } else if isHovering {
            shape.fill(ColorTokens.Sidebar.hoverFill)
        }
    }

    @ViewBuilder
    private var guides: some View {
        if spec.guides != .none {
            ZStack(alignment: .topLeading) {
                ForEach(Array(row.guideOwners.enumerated()), id: \.offset) { level, owner in
                    let isAccent = owner == accentGuideOwner
                    if spec.guides == .all || isAccent {
                        Rectangle()
                            .fill(isAccent ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.1))
                            .frame(width: 1, height: height + spec.rowGap)
                            .offset(x: guideX(level))
                    }
                }
            }
        }
    }

    private func guideX(_ level: Int) -> CGFloat {
        let column = spec.chevronWidth > 0 ? spec.chevronWidth / 2 : spec.iconFrame / 2
        return spec.outerPadding + CGFloat(level) * spec.indent + spec.innerPadding + column
    }
}
