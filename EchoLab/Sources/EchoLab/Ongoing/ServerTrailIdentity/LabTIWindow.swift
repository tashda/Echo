import SwiftUI

/// The rail and the tree beside it, enough of Echo's window to feel how a minimised card is found
/// again. Click a card's header to minimise it; click its trail item, chip or row to bring it back.
struct LabTIWindow: View {
    let look: LabTILook
    var servers: [LabTIServer] = Array(LabTIServer.all.prefix(5))
    @State private var minimized: Set<String> = ["test", "norway"]
    @State private var selected = "prod"
    @State private var railHover = false
    @State private var hovered: String?
    @State private var trayOpen = false
    @Environment(\.echoMotion) private var motion

    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var collapsedWidth: CGFloat { itemSize + railPad * 2 }
    private var isExpanded: Bool { look.names == .expand && railHover }
    private var open: [LabTIServer] { servers.filter { !minimized.contains($0.id) } }
    private var folded: [LabTIServer] { servers.filter { minimized.contains($0.id) } }
    private var railServers: [LabTIServer] { look.shelf == .tray ? open : servers }
    /// The leading space the tree keeps for the rail.
    private var railGutter: CGFloat { (look.style == .labelled ? SpacingTokens.xxl + SpacingTokens.xxs : collapsedWidth) + SpacingTokens.sm }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, railGutter)
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: minimized)
        .animation(motion.standard, value: selected)
    }

    // MARK: Actions

    private func minimize(_ server: LabTIServer) {
        minimized.insert(server.id)
        if selected == server.id, let next = open.first(where: { $0.id != server.id }) { selected = next.id }
    }

    private func restore(_ server: LabTIServer) {
        minimized.remove(server.id)
        selected = server.id
    }

    private func pick(_ server: LabTIServer) {
        if minimized.contains(server.id) { restore(server) } else { selected = server.id }
    }

    // MARK: Rail

    private var rail: some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) {
            ForEach(railServers) { server in railRow(server) }
            plus
            if look.shelf == .tray { tray }
        }
        .padding(railPad)
        .frame(width: isExpanded ? SpacingTokens.xxxl * 2.6 : nil)
        .glassEffect(.regular, in: .rect(cornerRadius: (itemSize + railPad * 2) / 2, style: .continuous))
        .onHover { railHover = $0 }
        .animation(motion.standard, value: isExpanded)
        .zIndex(2)
    }

    private func railRow(_ server: LabTIServer) -> some View {
        let isSelected = server.id == selected && !minimized.contains(server.id)
        return Button { pick(server) } label: {
            HStack(spacing: SpacingTokens.xs) {
                markView(server, isSelected: isSelected)
                if isExpanded {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(server.server.name).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                        Text(server.server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                    }
                    Spacer(minLength: SpacingTokens.none)
                }
            }
            .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
            .background {
                if isSelected {
                    Capsule().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                        .padding(SpacingTokens.micro * 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in hovered = inside ? server.id : (hovered == server.id ? nil : hovered) }
        .overlay(alignment: .leading) {
            if hovered == server.id, look.names == .bubble {
                bubble(server).offset(x: collapsedWidth + SpacingTokens.xxs).transition(.opacity)
            }
        }
        .help(look.names == .tooltip ? "\(server.server.name) · \(server.server.host)" : "")
        .zIndex(hovered == server.id ? 1 : 0)
    }

    private func markView(_ server: LabTIServer, isSelected: Bool) -> some View {
        VStack(spacing: SpacingTokens.micro) {
            LabTIMark(server: server, style: look.style, isSelected: isSelected,
                      isRing: look.shelf == .ring && minimized.contains(server.id),
                      size: look.style == .labelled ? SpacingTokens.lg + SpacingTokens.xs : itemSize)
            if look.style == .labelled {
                Text(String(server.server.name.prefix(8)))
                    .font(.system(size: 8.5, weight: .medium)).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
            }
        }
        .frame(width: look.style == .labelled ? SpacingTokens.xxl : itemSize,
               height: look.style == .labelled ? SpacingTokens.xxl + SpacingTokens.xxs : itemSize)
    }

    private func bubble(_ server: LabTIServer) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(server.server.name).font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary)
            Text(server.server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs2)
        .glassEffect(.regular, in: .capsule)
        .allowsHitTesting(false)
    }

    private var plus: some View {
        Image(systemName: "plus")
            .font(.system(size: LayoutTokens.Rail.toolSymbolSize))
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: itemSize, height: itemSize)
            .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
    }

    private var tray: some View {
        Button { trayOpen.toggle() } label: {
            Image(systemName: "tray.full")
                .font(.system(size: LayoutTokens.Rail.toolSymbolSize))
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: itemSize, height: itemSize)
                .overlay(alignment: .topTrailing) {
                    if !folded.isEmpty {
                        Text("\(folded.count)").font(.system(size: 9, weight: .bold)).foregroundStyle(ColorTokens.Text.onFill)
                            .padding(.horizontal, SpacingTokens.xxs1).padding(.vertical, SpacingTokens.micro)
                            .background(ColorTokens.accent, in: Capsule())
                    }
                }
                .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $trayOpen, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Text("Minimized").font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs2)
                if folded.isEmpty {
                    Text("Nothing is minimized").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
                        .padding(SpacingTokens.sm)
                }
                ForEach(folded) { server in
                    Button { restore(server); trayOpen = false } label: {
                        HStack(spacing: SpacingTokens.xs) {
                            LabTIMark(server: server, style: look.style, size: SpacingTokens.lg)
                            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                                Text(server.server.name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary)
                                Text(server.server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            Spacer(minLength: SpacingTokens.md)
                        }
                        .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, SpacingTokens.xxs)
            .frame(minWidth: SpacingTokens.xxxl * 3)
        }
    }

    // MARK: Tree

    private var tree: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.xs) {
                if look.shelf == .stripTop, !folded.isEmpty { strip }
                ForEach(treeServers) { server in card(server) }
                if look.shelf == .section, !folded.isEmpty { section }
                if look.shelf == .stripBottom, !folded.isEmpty { strip }
            }
            .padding(.trailing, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs1)
        }
        .scrollIndicators(.hidden)
        .labScrollSizing()
    }

    /// Cards in the list: all of them in order, or only the open ones.
    private var treeServers: [LabTIServer] {
        look.shelf == .inList ? servers : open
    }

    @ViewBuilder
    private func card(_ server: LabTIServer) -> some View {
        if minimized.contains(server.id) {
            Button { restore(server) } label: {
                LabSHHeader(server: server.server, look: .today, showsChevron: true)
                    .padding(.bottom, SpacingTokens.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .workspaceCard()
            .transition(.opacity)
        } else {
            LabSHCard(server: server.server, look: .today, rowLimit: 3, selectedRow: nil)
                .overlay(alignment: .topTrailing) {
                    Color.clear.frame(width: SpacingTokens.xl2, height: SpacingTokens.xl).contentShape(Rectangle())
                        .onTapGesture { minimize(server) }
                }
                .transition(.opacity)
        }
    }

    /// SH1: folded cards as rows, under a heading.
    private var section: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            Text("Minimized").font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxs)
            ForEach(folded) { server in
                Button { restore(server) } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        Circle().fill(server.server.color).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                        Text(server.server.name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                        Text(server.server.product).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                        Spacer(minLength: SpacingTokens.xxs)
                        Image(systemName: "chevron.up").font(SidebarRowConstants.sectionChevronFont).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .frame(height: SpacingTokens.lg + SpacingTokens.xxs1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Color.clear.frame(height: SpacingTokens.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
    }

    /// SH2 and SH3: folded cards as chips.
    private var strip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: SpacingTokens.xxxl * 1.6), spacing: SpacingTokens.xxs, alignment: .leading)],
                  alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(folded) { server in
                Button { restore(server) } label: {
                    HStack(spacing: SpacingTokens.xxs2) {
                        LabTIMark(server: server, style: look.style, size: SpacingTokens.md1)
                        Text(server.server.name).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.xxs)
                    .glassEffect(.regular, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpacingTokens.xxs)
    }
}
