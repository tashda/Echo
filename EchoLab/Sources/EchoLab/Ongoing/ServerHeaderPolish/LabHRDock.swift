import SwiftUI

/// The icon menu in one of round 50's six treatments, on a coloured surface (`onColour`) or on the
/// card. Click an icon to switch section; the pill, disc or line slides.
struct LabHRDockBar: View {
    let treatment: LabHRDock
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
                    icon(section).frame(maxWidth: .infinity).frame(height: height).contentShape(Rectangle())
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
            .font(TypographyTokens.prominent.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(glyph(isSelected: isSelected))
            .background {
                if isSelected { indicator.matchedGeometryEffect(id: "selection", in: slide) }
            }
    }

    private func glyph(isSelected: Bool) -> AnyShapeStyle {
        switch treatment {
        case .glass:
            return isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.Sidebar.symbol)
        case .pill:
            if onColour { return isSelected ? AnyShapeStyle(surface) : AnyShapeStyle(ColorTokens.Text.onFill.opacity(0.78)) }
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

    /// The pill, disc, line or small capsule under the selected icon.
    @ViewBuilder
    private var indicator: some View {
        switch treatment {
        case .glass:
            Color.clear
        case .tinted:
            Color.clear
        case .flat:
            Capsule().fill(onColour ? Color.white.opacity(0.22) : tint.opacity(0.16)).padding(.vertical, SpacingTokens.micro * 2)
                .padding(.horizontal, SpacingTokens.xxs)
        case .pill:
            Capsule().fill(onColour ? Color.white : tint.opacity(0.18)).padding(.vertical, SpacingTokens.micro * 2)
                .padding(.horizontal, SpacingTokens.xxs)
        case .recessed:
            Capsule()
                .fill(onColour ? ColorTokens.Workspace.railSelection : ColorTokens.Workspace.railSelection)
                .shadow(ShadowTokens.railSelection)
                .padding(.vertical, SpacingTokens.micro * 3).padding(.horizontal, SpacingTokens.xxs)
        case .underline:
            Capsule().fill(onColour ? Color.white : tint).frame(height: SpacingTokens.xxxs)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.horizontal, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxxs)
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
