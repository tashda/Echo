import SwiftUI

/// One server's item in the trail in a given state and mark (round 55). The white selection disc
/// is drawn when it is the selected server, as in Echo's trail.
struct LabTSItem: View {
    let server: LabTIServer
    let state: LabTSState
    let look: LabTSLook
    var isSelected = false

    private var size: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var tint: Color { server.server.color }
    private var isOpen: Bool { state == .open || state == .connecting }

    var body: some View {
        ZStack {
            if isSelected {
                Capsule().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                    .padding(LayoutTokens.Rail.selectionInset)
            }
            underMark
            LabTIMark(server: server, style: .monogram, custom: customisation,
                      isSelected: look.mark == .weight ? state == .open : isSelected,
                      isRing: state == .minimized && look.mark == .ring, size: size)
                .opacity(markOpacity)
            overMark
        }
        .frame(width: size, height: size)
        .modifier(LabTSBreathing(isActive: state == .connecting))
        .contentShape(Circle())
    }

    private var customisation: LabTICustomisation {
        var custom = LabTICustomisation()
        let greyMinimized = state == .minimized && look.mark == .grey
        let greyRecent = state == .recent && look.recentLook == .grey
        if greyMinimized || greyRecent { custom.color = Color.secondary }
        return custom
    }

    private var markOpacity: Double {
        switch state {
        case .minimized: look.mark == .dim ? 0.55 : (look.mark == .weight ? 0.85 : 1)
        case .recent: look.recentLook == .grey ? 0.8 : 0.38
        default: 1
        }
    }

    /// Behind the letters.
    @ViewBuilder
    private var underMark: some View {
        if isOpen || state == .minimized {
            switch look.mark {
            case .disc where isOpen:
                Circle().fill(tint.opacity(0.14)).padding(SpacingTokens.micro * 3)
            case .chip where isOpen:
                Circle().fill(Color.clear).glassEffect(.regular, in: .circle).padding(SpacingTokens.xxxs)
            default:
                EmptyView()
            }
        }
    }

    /// Over or beside the letters.
    @ViewBuilder
    private var overMark: some View {
        if isOpen {
            switch look.mark {
            case .dot:
                Circle().fill(tint).frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading).offset(x: -SpacingTokens.xxs)
            case .bar:
                Capsule().fill(tint).frame(width: SpacingTokens.nano, height: SpacingTokens.sm2)
                    .frame(maxWidth: .infinity, alignment: .leading).offset(x: -SpacingTokens.xxs1)
            case .badge:
                Circle().fill(tint).frame(width: SpacingTokens.xxs3, height: SpacingTokens.xxs3)
                    .overlay { Circle().strokeBorder(ColorTokens.Workspace.canvas, lineWidth: 1) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(SpacingTokens.xxs)
            case .line:
                Circle().stroke(tint.opacity(0.55), lineWidth: 1).padding(SpacingTokens.xxs)
            case .under:
                Capsule().fill(tint).frame(width: SpacingTokens.sm, height: SpacingTokens.xxxs)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, SpacingTokens.xxs)
            default:
                EmptyView()
            }
        }
        if state == .recent, look.recentLook == .clock {
            Image(systemName: "clock.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

/// A connecting server breathes, as Echo's trail already does.
struct LabTSBreathing: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        if isActive {
            content.phaseAnimator([false, true]) { view, dimmed in
                view.opacity(dimmed ? 0.4 : 1).scaleEffect(dimmed ? 0.94 : 1)
            } animation: { _ in .easeInOut(duration: 0.55) }
        } else {
            content
        }
    }
}

/// The trail and the cards beside it. Click a card's header to minimize it, its item to bring it back;
/// click a recent server to connect it; right-click a connected one to disconnect it.
struct LabTSWindow: View {
    let look: LabTSLook
    @State private var active = ["prod", "test", "dev", "mssql25"]
    @State private var recents = ["norway", "tippr", "pgservices", "readsoft", "corporate"]
    @State private var minimized: Set<String> = ["test"]
    @State private var selected = "prod"
    @State private var connecting: String?
    @State private var popoverOpen = false
    @Namespace private var trail
    @Environment(\.echoMotion) private var motion

    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var shownRecents: [String] { Array(recents.prefix(look.count.count)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, itemSize + railPad * 2 + SpacingTokens.sm + SpacingTokens.xxs1)
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(active.filter { !minimized.contains($0) }, id: \.self) { id in
                LabHCCard(server: LabTIServer.named(id).server, look: LabHCLook(), rowLimit: 2, interactive: false)
                    .overlay(alignment: .topTrailing) {
                        Color.clear.frame(width: SpacingTokens.xxxl * 3, height: SpacingTokens.xxxl - SpacingTokens.xs).contentShape(Rectangle())
                            .onTapGesture { withAnimation(motion.standard) { _ = minimized.insert(id) } }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .padding(.trailing, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Trail

    @ViewBuilder
    private var rail: some View {
        switch look.recents {
        case .none:
            pill { activeItems }
        case .samePill:
            pill {
                activeItems
                if !shownRecents.isEmpty {
                    Capsule().fill(ColorTokens.Text.primary.opacity(0.12)).frame(width: itemSize * 0.6, height: 1)
                        .padding(.vertical, SpacingTokens.xxxs)
                }
                recentItems
            }
        case .twoPills:
            VStack(spacing: SpacingTokens.xs) {
                pill { activeItems }
                if !shownRecents.isEmpty { pill { recentItems } }
            }
        case .button:
            pill {
                activeItems
                Button { popoverOpen.toggle() } label: {
                    Image(systemName: "clock").font(.system(size: LayoutTokens.Rail.toolSymbolSize)).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: itemSize, height: itemSize)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $popoverOpen, arrowEdge: .trailing) { recentsList }
            }
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) { content() }
            .padding(railPad)
            .glassEffect(.regular, in: .capsule)
            .animation(motion.standard, value: active)
            .animation(motion.standard, value: recents)
    }

    @ViewBuilder
    private var activeItems: some View {
        ForEach(active, id: \.self) { id in
            let server = LabTIServer.named(id)
            Button { if minimized.contains(id) { withAnimation(motion.standard) { _ = minimized.remove(id) } }; selected = id } label: {
                LabTSItem(server: server, state: connecting == id ? .connecting : (minimized.contains(id) ? .minimized : .open),
                          look: look, isSelected: selected == id && !minimized.contains(id))
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: id, in: trail)
            .contextMenu { Button("Disconnect") { disconnect(id) } }
            .help(server.server.name)
        }
    }

    @ViewBuilder
    private var recentItems: some View {
        ForEach(shownRecents, id: \.self) { id in
            let server = LabTIServer.named(id)
            Button { connect(id) } label: {
                LabTSItem(server: server, state: connecting == id ? .connecting : .recent, look: look)
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: id, in: trail)
            .help("\(server.server.name): click to connect")
        }
    }

    private var recentsList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            Text("Recent").font(SidebarRowConstants.sectionHeadingFont).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs2)
            ForEach(shownRecents, id: \.self) { id in
                let server = LabTIServer.named(id)
                Button { popoverOpen = false; connect(id) } label: {
                    HStack(spacing: SpacingTokens.xs) {
                        LabTIMark(server: server, style: .monogram, size: SpacingTokens.lg)
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

    // MARK: Actions

    /// The server breathes while it connects, then glides up into the connected group.
    private func connect(_ id: String) {
        guard connecting == nil else { return }
        connecting = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(motion.standard) {
                recents.removeAll { $0 == id }
                active.append(id)
                connecting = nil
                selected = id
            }
        }
    }

    private func disconnect(_ id: String) {
        withAnimation(motion.standard) {
            active.removeAll { $0 == id }
            minimized.remove(id)
            recents.insert(id, at: 0)
            if selected == id { selected = active.first ?? "" }
        }
    }
}

/// Each mark on a small trail: an open and selected server, an open one, a minimized one, a recent one.
struct LabTSMarksGallery: View {
    let look: LabTSLook

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 3),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabTSMark.allCases, id: \.self) { mark in
                    let current = look.with(mark: mark)
                    HStack(alignment: .top, spacing: SpacingTokens.sm) {
                        VStack(spacing: LayoutTokens.Rail.itemSpacing) {
                            LabTSItem(server: .named("prod"), state: .open, look: current, isSelected: true)
                            LabTSItem(server: .named("dev"), state: .open, look: current)
                            LabTSItem(server: .named("test"), state: .minimized, look: current)
                            LabTSItem(server: .named("norway"), state: .recent, look: current)
                        }
                        .padding(LayoutTokens.Rail.pillPadding)
                        .glassEffect(.regular, in: .capsule)
                        Text(mark.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
