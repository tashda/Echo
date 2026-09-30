import SwiftUI

/// The section icons in each header style. Right-click an icon for its section's own menu (what
/// right-clicking its folder gave before the dock), with Dock choices under it; right-click the
/// empty space for the Dock choices alone.
struct LabSCDock: View {
    let server: LabSCServer
    let state: LabSCState
    let options: LabSCOptions
    let onChoose: (String) -> Void
    let onCustomize: () -> Void

    private var sections: [LabSCSection] { state.dock(for: server).compactMap(server.section) }
    private var chosen: String { state.chosenSection(of: server) }

    var body: some View {
        switch options.header {
        case .today: tiles(height: LayoutTokensToday.buttonHeight, font: TypographyTokens.prominent, labelsCurrent: false)
        case .labelled: tiles(height: options.density.dockHeight, font: options.density.dockIconFont, labelsCurrent: true)
        case .navigator: navigator
        case .segmented: segmented
        case .oneLine: compact
        case .sectionMenu: sectionMenu
        case .glass: glass
        }
    }

    // MARK: - Styles

    private func tiles(height: CGFloat, font: Font, labelsCurrent: Bool) -> some View {
        HStack(spacing: SpacingTokens.xxxs) {
            ForEach(sections) { section in
                button(section, font: font) { isCurrent in
                    HStack(spacing: SpacingTokens.xxs2) {
                        LabSCSymbol(name: section.symbol, color: section.color, style: options.dockIcons, isCurrent: isCurrent && options.dockIcons == .mono, font: font)
                        if labelsCurrent && isCurrent {
                            Text(section.title).font(TypographyTokens.detail.weight(.semibold)).lineLimit(1).fixedSize()
                        }
                    }
                    .frame(maxWidth: labelsCurrent && !isCurrent ? height * 1.4 : .infinity)
                    .frame(height: height)
                    .background { if isCurrent { pill } }
                }
                .frame(maxWidth: labelsCurrent && section.id == chosen ? .infinity : nil)
            }
            moreButton(font: font, height: height)
        }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .contentShape(Rectangle())
        .contextMenu { dockMenu }
    }

    private var navigator: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(sections) { section in
                button(section, font: options.density.dockIconFont) { isCurrent in
                    LabSCSymbol(name: section.symbol, color: section.color, style: options.dockIcons, isCurrent: isCurrent, font: options.density.dockIconFont)
                        .frame(maxWidth: .infinity)
                        .frame(height: options.density.dockHeight)
                }
            }
            moreButton(font: options.density.dockIconFont, height: options.density.dockHeight)
        }
        .padding(.horizontal, SpacingTokens.xxs)
        .contentShape(Rectangle())
        .contextMenu { dockMenu }
    }

    private var segmented: some View {
        Picker("Section", selection: Binding(get: { chosen }, set: onChoose)) {
            ForEach(sections) { section in
                Image(systemName: section.symbol).help(section.title).tag(section.id)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(options.density == .large ? .large : options.density == .compact ? .small : .regular)
        .padding(.horizontal, SpacingTokens.xs)
        .contextMenu { dockMenu }
    }

    private var compact: some View {
        HStack(spacing: SpacingTokens.micro) {
            ForEach(sections) { section in
                button(section, font: options.density.labelFont) { isCurrent in
                    LabSCSymbol(name: section.symbol, color: section.color, style: options.dockIcons, isCurrent: isCurrent && options.dockIcons == .mono, font: options.density.labelFont)
                        .frame(width: options.density.dockHeight - SpacingTokens.xxs, height: options.density.dockHeight - SpacingTokens.xxs)
                        .background { if isCurrent { pill } }
                }
            }
            moreButton(font: options.density.labelFont, height: options.density.dockHeight - SpacingTokens.xxs)
        }
        .contextMenu { dockMenu }
    }

    private var sectionMenu: some View {
        let current = server.section(chosen)
        return Menu {
            ForEach(server.sections) { section in
                Button { onChoose(section.id) } label: { Label(section.title, systemImage: section.symbol) }
            }
            Divider()
            dockMenu
        } label: {
            Label(current?.title ?? "", systemImage: current?.symbol ?? "questionmark")
                .font(options.density.labelFont.weight(.semibold))
        }
        .menuStyle(.button)
        .buttonStyle(.accessoryBar)
        .fixedSize()
        .padding(.horizontal, SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var glass: some View {
        GlassEffectContainer {
            HStack(spacing: SpacingTokens.xxxs) {
                ForEach(sections) { section in
                    button(section, font: options.density.dockIconFont) { isCurrent in
                        LabSCSymbol(name: section.symbol, color: section.color, style: options.dockIcons, isCurrent: isCurrent, font: options.density.dockIconFont)
                            .frame(width: options.density.dockHeight + SpacingTokens.xxs, height: options.density.dockHeight)
                            .background { if isCurrent { Capsule().fill(ColorTokens.Sidebar.selectedFill) } }
                    }
                }
                moreButton(font: options.density.dockIconFont, height: options.density.dockHeight)
            }
            .padding(SpacingTokens.nano)
            .glassEffect(.regular, in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .contextMenu { dockMenu }
    }

    // MARK: - Parts

    private var pill: some View {
        RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
            .fill(ColorTokens.Sidebar.selectedFill)
    }

    private func button<Label: View>(_ section: LabSCSection, font: Font, @ViewBuilder label: @escaping (Bool) -> Label) -> some View {
        let isCurrent = section.id == chosen
        let isLoading = state.loading.contains(state.sectionKey(server, section.id))
        return Button { onChoose(section.id) } label: {
            label(isCurrent)
                .opacity(isLoading ? 0.25 : 1)
                .overlay { if isLoading { ProgressView().controlSize(.small) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .contextMenu {
            ForEach(section.menu) { item in
                if item.isDivider { Divider() } else { Button(item.title, systemImage: item.symbol) {} }
            }
            Divider()
            dockMenu
        }
    }

    /// More appears only when some sections are left out of the dock; it lists them.
    @ViewBuilder
    private func moreButton(font: Font, height: CGFloat) -> some View {
        let overflow = state.overflow(for: server)
        if !overflow.isEmpty {
            Menu {
                ForEach(overflow) { section in
                    Button { onChoose(section.id) } label: { Label(section.title, systemImage: section.symbol) }
                }
            } label: {
                Image(systemName: "chevron.right.2").font(font.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(minWidth: height, minHeight: height)
            .help("More sections")
        }
    }

    @ViewBuilder
    private var dockMenu: some View {
        Menu("Dock") {
            ForEach(server.sections) { section in
                Toggle(section.title, isOn: Binding(
                    get: { state.dock(for: server).contains(section.id) },
                    set: { _ in state.toggle(section.id, in: server) }
                ))
            }
            Divider()
            Button("Use \(server.engine.rawValue) Defaults") { state.resetDock(for: server) }
            Button("Customize Dock", action: onCustomize)
        }
    }
}

/// Echo's current dock metrics, reproduced for H0.
enum LayoutTokensToday {
    static let buttonHeight: CGFloat = SpacingTokens.lg2
}
