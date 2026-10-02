import SwiftUI

/// A server card with round 53's header: click the header to collapse it, click an icon to switch
/// section. The look is the owner's preset from round 50 (F5) plus what the user may customise.
struct LabHCCard: View {
    let server: LabSHServer
    let look: LabHCLook
    var rowLimit: Int?
    @State private var isOpen = true
    @State private var isHovering = false
    @State private var section = LabHRSection.databases
    @Environment(\.colorScheme) private var scheme
    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var tint: Color { look.tint(for: server, scheme: scheme) }
    private var textColor: Color { look.textColor(on: tint) }

    var body: some View {
        let look = look.applied
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                header(look)
                if isOpen { dock(look).transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top))) }
            }
            .padding(.bottom, isOpen ? SpacingTokens.xxs2 + (look.edge == .rounded ? SpacingTokens.xxs : 0) : SpacingTokens.none)
            .background { LabHCBanner(look: look, tint: tint).allowsHitTesting(false) }
            .overlay(alignment: .bottom) {
                if look.chevron == .handle {
                    LabHCHandle(isOpen: isOpen, isHovering: isHovering, motion: look.motion, color: textColor)
                }
            }
            .zIndex(1)
            if isOpen {
                VStack(spacing: SpacingTokens.none) {
                    ForEach(rows, id: \.self) { LabSHRow(title: $0, isSelected: false) }
                }
                .padding(.bottom, SpacingTokens.xxs)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
        .onHover { isHovering = $0 }
    }

    private var rows: [String] { rowLimit.map { Array(server.rows.prefix($0)) } ?? server.rows }

    private func toggle(_ look: LabHCLook) {
        withAnimation(look.motion.animation ?? .linear(duration: 0)) { isOpen.toggle() }
    }

    // MARK: Header

    private func header(_ look: LabHCLook) -> some View {
        let lines = VStack(alignment: look.align == .centred ? .center : .leading, spacing: SpacingTokens.xxxs) {
            if let eyebrow = eyebrowText(look) {
                Text(eyebrow).font(.system(size: 11, weight: .bold)).tracking(1.3)
                    .foregroundStyle(textColor.opacity(0.82)).lineLimit(1).contentTransition(.opacity)
            }
            Text(server.name).font(look.nameFont).foregroundStyle(textColor).lineLimit(1)
            if look.eyebrow == .none {
                Text("\(server.product) · \(section.title)").font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(textColor.opacity(0.82)).lineLimit(1)
            }
        }
        return HStack(spacing: SpacingTokens.xs) {
            if look.align == .centred { Spacer(minLength: SpacingTokens.lg) }
            lines
            Spacer(minLength: SpacingTokens.xxs)
            if look.chevron != .handle {
                LabHCChevronView(kind: look.chevron, isOpen: isOpen, isHovering: isHovering, motion: look.motion,
                                 shows: look.shows, color: textColor, count: server.rows.count)
            }
        }
        .overlay(alignment: .trailing) {
            if look.align == .centred, look.chevron != .handle {
                // Centred type leaves the chevron where it is.
                Color.clear.frame(width: 1)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.top, look.density.vertical)
        .padding(.bottom, look.density == .compact ? SpacingTokens.xxs : (look.density == .roomy ? SpacingTokens.xs : SpacingTokens.xxs2))
        .contentShape(Rectangle())
        .onTapGesture { toggle(look) }
    }

    private func eyebrowText(_ look: LabHCLook) -> String? {
        switch look.eyebrow {
        case .section: section.title.uppercased()
        case .engine: server.engineCaps
        case .engineSection: "\(server.engineCaps) · \(section.title.uppercased())"
        case .none: nil
        }
    }

    // MARK: Icon menu

    /// Icons straight on the colour; the selected one turns filled and bold. No capsule, no pill.
    private func dock(_ look: LabHCLook) -> some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(LabHRSection.allCases, id: \.self) { item in
                let isSelected = item == section
                Button { withAnimation(.smooth(duration: 0.25)) { section = item } } label: {
                    Image(systemName: item.symbol)
                        .symbolVariant(isSelected ? .fill : .none)
                        .font(.system(size: look.iconSize.points, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(textColor.opacity(isSelected ? 1 : 0.72))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(maxWidth: .infinity).frame(height: SpacingTokens.lg + SpacingTokens.xxs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.title)
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2 + SidebarRowConstants.rowOuterHorizontalPadding)
    }
}

/// The banner: the chosen fill, ending against the card as the chosen edge says.
struct LabHCBanner: View {
    let look: LabHCLook
    let tint: Color

    var body: some View {
        switch look.edge {
        case .sharp:
            fill
        case .hairline:
            fill.overlay(alignment: .bottom) { Color.white.opacity(0.35).frame(height: 0.5) }
        case .soft:
            fill.mask { LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.62),
                                               .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom) }
        case .frosted:
            fill.overlay(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial).frame(height: SpacingTokens.xl + SpacingTokens.xxs)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            }
            .mask { LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8),
                                           .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom) }
        case .rounded:
            fill.clipShape(UnevenRoundedRectangle(bottomLeadingRadius: SpacingTokens.md1, bottomTrailingRadius: SpacingTokens.md1, style: .continuous))
        }
    }

    @ViewBuilder
    private var fill: some View {
        switch look.fill {
        case .gradient:
            LinearGradient(colors: [tint.opacity(0.92), tint], startPoint: .top, endPoint: .bottom)
        case .flat:
            tint
        case .frosted:
            ZStack { Rectangle().fill(.regularMaterial); tint.opacity(0.62) }
        }
    }
}

/// The tree's column with the cards stacked.
struct LabHCColumn<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: SpacingTokens.xs) { content }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(ColorTokens.Workspace.canvas)
    }
}

/// A card per variant, two to a row (the chevrons, the presets).
struct LabHCGallery: View {
    let variants: [(title: String, look: LabHCLook)]
    let server: LabSHServer
    var columns = 2
    var rowLimit: Int? = 1

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: columns),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(Array(variants.enumerated()), id: \.offset) { _, variant in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(variant.title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabHCCard(server: server, look: variant.look, rowLimit: rowLimit)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
