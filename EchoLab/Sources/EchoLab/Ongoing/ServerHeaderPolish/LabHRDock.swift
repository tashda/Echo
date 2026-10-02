import SwiftUI

/// The icon menu in one of round 50's six treatments, on a coloured surface (`onColour`) or on the
/// card. Click an icon to switch section; the pill, disc or line slides.
struct LabHRDockBar: View {
    let treatment: LabHRDock
    var iconStyle = LabHRIcon.semibold14
    var pillShape = LabHRPill.wide
    let tint: Color
    let onColour: Bool
    /// The surface's own colour, for the tinted glass and the recess.
    let surface: Color
    @Binding var selected: LabHRSection
    @Namespace private var slide

    private let height = SpacingTokens.lg + SpacingTokens.xxs

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { section in
                Button { withAnimation(.smooth(duration: 0.28)) { selected = section } } label: {
                    icon(section)
                        .frame(maxWidth: .infinity).frame(height: height)
                        .background { if section == selected { indicator.matchedGeometryEffect(id: "selection", in: slide) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(section.title)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .background { capsule }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
    }

    // MARK: Icons

    private func icon(_ section: LabHRSection) -> some View {
        let isSelected = section == selected
        return Image(systemName: section.symbol)
            .symbolVariant(isSelected && iconStyle.isFilled ? .fill : .none)
            .font(isSelected ? iconStyle.font : TypographyTokens.prominent.weight(.medium))
            .foregroundStyle(glyph(isSelected: isSelected))
    }

    private func glyph(isSelected: Bool) -> AnyShapeStyle {
        switch treatment {
        case .glass:
            return isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol)
        case .pill:
            if onColour { return isSelected ? AnyShapeStyle(surface) : AnyShapeStyle(ColorTokens.Text.onFill.opacity(iconStyle.othersOpacity)) }
            return isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol)
        case .recessed:
            if onColour { return AnyShapeStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.onFill.opacity(0.7)) }
            return isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol)
        case .tinted, .flat, .underline:
            if onColour { return AnyShapeStyle(isSelected ? ColorTokens.Text.onFill : ColorTokens.Text.onFill.opacity(0.72)) }
            return isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol)
        }
    }

    // MARK: Selection

    /// The pill, disc, line or small capsule under the selected icon, drawn in the whole cell.
    @ViewBuilder
    private var indicator: some View {
        switch treatment {
        case .glass, .tinted:
            Color.clear
        case .underline:
            Capsule().fill(onColour ? Color.white : tint).frame(height: SpacingTokens.xxxs)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.horizontal, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxxs)
        case .flat, .pill, .recessed:
            pillView
        }
    }

    private var pillFill: Color {
        switch treatment {
        case .pill: onColour ? Color.white : tint.opacity(0.18)
        case .flat: onColour ? Color.white.opacity(0.22) : tint.opacity(0.16)
        default: ColorTokens.Workspace.railSelection
        }
    }

    @ViewBuilder
    private var pillView: some View {
        let shape = pillGeometry
        switch pillShape {
        case .ring:
            shape.stroke(onColour ? Color.white : tint, lineWidth: 1.5).frame(width: pillSize.width, height: pillSize.height)
        case .glass:
            Color.clear.frame(width: pillSize.width, height: pillSize.height).glassEffect(.regular, in: .capsule)
        case .raised:
            shape.fill(pillFill).shadow(color: .black.opacity(0.28), radius: SpacingTokens.xxs, y: SpacingTokens.xxxs)
                .frame(width: pillSize.width, height: pillSize.height)
        default:
            shape.fill(pillFill).frame(width: pillSize.width, height: pillSize.height)
        }
    }

    private var pillGeometry: AnyShape {
        switch pillShape {
        case .disc: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
        default: AnyShape(Capsule())
        }
    }

    private var pillSize: CGSize {
        switch pillShape {
        case .wide: CGSize(width: 52, height: 24)
        case .disc: CGSize(width: 28, height: 28)
        case .square: CGSize(width: 32, height: 26)
        default: CGSize(width: 42, height: 24)
        }
    }

    // MARK: Capsule

    @ViewBuilder
    private var capsule: some View {
        switch treatment {
        case .glass:
            Color.clear.glassEffect(.regular, in: .capsule)
        case .tinted:
            Color.clear.glassEffect(.regular.tint((onColour ? surface.opacity(0.55) : tint.opacity(0.18))), in: .capsule)
        case .flat:
            Capsule().fill(onColour ? Color.white.opacity(0.16) : ColorTokens.Text.primary.opacity(0.06))
        case .recessed:
            Capsule().fill(onColour ? Color.black.opacity(0.2) : ColorTokens.Text.primary.opacity(0.07))
                .overlay { Capsule().strokeBorder(Color.black.opacity(onColour ? 0.18 : 0.06), lineWidth: 0.5) }
        case .pill, .underline:
            Color.clear
        }
    }
}
