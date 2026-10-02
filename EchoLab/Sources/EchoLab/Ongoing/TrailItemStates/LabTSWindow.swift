import SwiftUI

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
    @Namespace private var trail
    @Environment(\.echoMotion) private var motion

    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var shownRecents: [String] { look.isToday ? [] : Array(recents.prefix(look.count.count)) }
    private var openIDs: [String] { active.filter { !minimized.contains($0) } }
    private var minimizedIDs: [String] { active.filter { minimized.contains($0) } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, itemSize + railPad * 2 + SpacingTokens.sm + SpacingTokens.xxs1)
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: active)
        .animation(motion.standard, value: minimized)
        .animation(motion.standard, value: recents)
    }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(openIDs, id: \.self) { id in
                LabHCCard(server: LabTIServer.named(id).server, look: LabHCLook(), rowLimit: 2, interactive: false)
                    .overlay(alignment: .topTrailing) {
                        Color.clear.frame(width: SpacingTokens.xxxl * 3, height: SpacingTokens.xxxl - SpacingTokens.xs).contentShape(Rectangle())
                            .onTapGesture { minimize(id) }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .padding(.trailing, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Trail

    private var rail: some View {
        VStack(spacing: SpacingTokens.xs) {
            pill { connectedItems }
            if !shownRecents.isEmpty {
                pill {
                    recentItems
                    if look.form == .inPill { connectButton }
                }
            }
            if !look.isToday { connectOutside }
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) { content() }
            .padding(railPad)
            .glassEffect(.regular, in: .capsule)
    }

    /// The connected pill: open servers, the hairline, minimized servers. Today: all in order, a ring, a +.
    @ViewBuilder
    private var connectedItems: some View {
        if look.isToday {
            ForEach(active, id: \.self) { item($0, ring: minimized.contains($0)) }
            plusToday
        } else {
            ForEach(openIDs, id: \.self) { item($0) }
            if !openIDs.isEmpty, !minimizedIDs.isEmpty { divider }
            ForEach(minimizedIDs, id: \.self) { item($0) }
            if look.form == .inPill, shownRecents.isEmpty { connectButton }
        }
    }

    @ViewBuilder
    private var recentItems: some View {
        ForEach(shownRecents, id: \.self) { id in
            let server = LabTIServer.named(id)
            Button { connect(id) } label: {
                LabTIMark(server: server, style: .monogram, custom: recentColour, size: itemSize)
                    .opacity(look.recent == .dim38 ? 0.38 : (look.recent == .dim50 ? 0.5 : 0.8))
                    .modifier(LabTSBreathing(isActive: connecting == id))
                    .frame(width: itemSize, height: itemSize)
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: id, in: trail)
            .help("\(server.server.name): click to connect")
        }
    }

    private var recentColour: LabTICustomisation {
        var custom = LabTICustomisation()
        if look.recent == .grey { custom.color = Color.secondary }
        return custom
    }

    /// One connected server: today's mark and the white disc when it is the one in view.
    private func item(_ id: String, ring: Bool = false) -> some View {
        let server = LabTIServer.named(id)
        let isSelected = selected == id && !minimized.contains(id)
        return Button { restoreOrSelect(id) } label: {
            ZStack {
                if selected == id {
                    Capsule().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                        .padding(LayoutTokens.Rail.selectionInset)
                        .matchedGeometryEffect(id: "disc", in: trail)
                }
                LabTIMark(server: server, style: .monogram, isSelected: isSelected, isRing: ring, size: itemSize)
            }
            .frame(width: itemSize, height: itemSize)
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: id, in: trail)
        .contextMenu { Button("Disconnect") { disconnect(id) } }
        .help(server.server.name)
    }

    @ViewBuilder
    private var divider: some View {
        switch look.divider {
        case .line:
            Capsule().fill(ColorTokens.Text.primary.opacity(0.14)).frame(width: itemSize * 0.6, height: 1).padding(.vertical, SpacingTokens.xxs)
        case .full:
            Capsule().fill(ColorTokens.Text.primary.opacity(0.14)).frame(height: 1).padding(.vertical, SpacingTokens.xxs)
        case .gap:
            Color.clear.frame(width: 1, height: SpacingTokens.xxs)
        }
    }

    // MARK: Connect button

    private var connectGlyph: some View {
        Image(systemName: look.icon.symbol)
            .font(.system(size: LayoutTokens.Rail.toolSymbolSize))
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: itemSize, height: itemSize)
            .contentShape(Circle())
    }

    private var connectButton: some View {
        Button {} label: { connectGlyph }.buttonStyle(.plain).help("Connect to a Server")
    }

    @ViewBuilder
    private var connectOutside: some View {
        switch look.form {
        case .circle:
            Button {} label: { connectGlyph }.buttonStyle(.plain)
                .padding(railPad).glassEffect(.regular, in: .circle).help("Connect to a Server")
        case .bare:
            Button {} label: { connectGlyph }.buttonStyle(.plain).help("Connect to a Server")
        case .inPill:
            EmptyView()
        }
    }

    private var plusToday: some View {
        Image(systemName: "plus").font(.system(size: LayoutTokens.Rail.toolSymbolSize)).foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: itemSize, height: itemSize)
    }

    // MARK: Actions

    private func minimize(_ id: String) { _ = minimized.insert(id); if selected == id { selected = openIDs.first(where: { $0 != id }) ?? id } }

    private func restoreOrSelect(_ id: String) {
        minimized.remove(id)
        selected = id
    }

    /// The server breathes while it connects, then glides up into the connected pill.
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
            if selected == id { selected = openIDs.first ?? "" }
        }
    }
}
