import SwiftUI

enum LabSDCapsuleMetrics {
    /// Sections per row before M5 starts a second row.
    static func perRow(_ options: LabSDOptions) -> Int { options.limit.count ?? 5 }

    /// The dock row's slot: an ordinary row plus 8pt (Echo), plus a second row for M5.
    static func rowHeight(_ server: LabSDServer, options: LabSDOptions) -> CGFloat {
        let base = options.density.rowSlot + SpacingTokens.xs
        guard options.overflow == .secondRow, server.sections.count > perRow(options) else { return base }
        return base + options.density.capsuleHeight + SpacingTokens.xxs
    }
}

/// The section dock in every style the round compares. Right-click an icon for its section's
/// own menu; the » button handles sections that don't fit the way the overflow option says.
struct LabSDCapsule: View {
    let server: LabSDServer
    let chosen: String
    let options: LabSDOptions
    let onChoose: (String) -> Void

    private var arrangement: (shown: [LabSDSection], overflow: [LabSDSection]) { LabSDDockArrangement.arrange(server, options: options) }
    private var height: CGFloat { options.density.capsuleHeight }

    var body: some View {
        let sections = arrangement.shown
        Group {
            switch options.overflow {
            case .secondRow where sections.count > LabSDCapsuleMetrics.perRow(options):
                VStack(spacing: SpacingTokens.xxs) {
                    track(Array(sections.prefix(LabSDCapsuleMetrics.perRow(options))), more: false)
                    track(Array(sections.dropFirst(LabSDCapsuleMetrics.perRow(options))), more: false)
                }
            case .scroll where sections.count > LabSDCapsuleMetrics.perRow(options):
                scrollingTrack(sections)
            default:
                track(sections, more: !arrangement.overflow.isEmpty)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Tracks

    private func track(_ sections: [LabSDSection], more: Bool) -> some View {
        let shrink = options.overflow == .shrink && sections.count > 5 ? -1 : 0
        let hugs = options.capsule == .floating
        return HStack(spacing: hugs ? SpacingTokens.xxs : SpacingTokens.none) {
            ForEach(sections) { section in
                icon(section, shrink: shrink)
                    .frame(maxWidth: hugs ? nil : .infinity)
                    .frame(minWidth: hugs ? height + SpacingTokens.xs : nil)
            }
            if more { moreButton }
        }
        .padding(.horizontal, hugs ? SpacingTokens.xxs : SpacingTokens.xxs2)
        .frame(height: height)
        .modifier(LabSDCapsuleBackground(style: options.capsule))
        .frame(maxWidth: .infinity)
    }

    /// M3: every icon at its size; the capsule scrolls sideways and fades at its ends.
    private func scrollingTrack(_ sections: [LabSDSection]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: SpacingTokens.none) {
                ForEach(sections) { icon($0, shrink: 0).frame(width: height * 1.5) }
            }
            .padding(.horizontal, SpacingTokens.xxs2)
        }
        .scrollIndicators(.never)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                                     .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .frame(height: height)
        .modifier(LabSDCapsuleBackground(style: options.capsule))
    }

    private func icon(_ section: LabSDSection, shrink: Int) -> some View {
        LabSDDockIcon(section: section, isCurrent: section.id == chosen, options: options, shrink: shrink, height: height) {
            onChoose(section.id)
        }
    }

    // MARK: - More

    @ViewBuilder
    private var moreButton: some View {
        let isCurrent = chosen == LabSDTreeState.moreID || arrangement.overflow.contains { $0.id == chosen }
        let glyph = Image(systemName: "chevron.right.2")
            .font(options.density.dockIconFont(steps: options.size.steps).weight(.semibold))
            .foregroundStyle(isCurrent ? ColorTokens.accent : ColorTokens.Text.secondary)
            .frame(minWidth: height, minHeight: height)
            .contentShape(Rectangle())
        switch options.overflow {
        case .moreSection:
            Button { onChoose(LabSDTreeState.moreID) } label: { glyph }
                .buttonStyle(.plain)
                .help("More sections")
        case .menuWithActions:
            Menu {
                ForEach(arrangement.overflow) { section in
                    Menu {
                        Button("Show \(section.title)", systemImage: section.symbol) { onChoose(section.id) }
                        Divider()
                        LabSDMenuItems(items: section.menu)
                    } label: { Label(section.title, systemImage: section.symbol) }
                }
            } label: { glyph }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        default:
            Menu {
                ForEach(arrangement.overflow) { section in
                    Button { onChoose(section.id) } label: { Label(section.title, systemImage: section.symbol) }
                }
            } label: { glyph }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        }
    }
}

/// A section's own right-click items.
struct LabSDMenuItems: View {
    let items: [LabSDMenuItem]

    var body: some View {
        ForEach(items) { item in
            if item.isDivider { Divider() } else { Button(item.title, systemImage: item.symbol) {} }
        }
    }
}

/// The capsule's own look, per style.
struct LabSDCapsuleBackground: ViewModifier {
    let style: LabSDCapsuleStyle

    func body(content: Content) -> some View {
        switch style {
        case .clearGlass, .glassPill:
            content.glassEffect(.regular, in: .capsule)
        case .tintedGlass:
            content.glassEffect(.regular.tint(ColorTokens.accent.opacity(0.12)), in: .capsule)
        case .frostedGlass:
            content.background(ColorTokens.Sidebar.hoverFill, in: .capsule).glassEffect(.regular, in: .capsule)
        case .filledTrack, .raisedPill:
            content.background(ColorTokens.Sidebar.hoverFill, in: .capsule)
        case .edgedGlass:
            content
                .glassEffect(.regular, in: .capsule)
                .overlay(Capsule().strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.8), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: SpacingTokens.xxs, y: SpacingTokens.micro)
        case .floating:
            content
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .black.opacity(0.12), radius: SpacingTokens.xs, y: SpacingTokens.xxxs)
        case .bar:
            content.overlay(alignment: .bottom) { Divider().offset(y: SpacingTokens.xxs) }
        case .underline:
            content
        }
    }
}
