import SwiftUI

/// The trail and three server cards, enough of Echo's window to feel a card go into the trail.
/// Click a card's header to minimize it; click its dashed-ring item to bring it back. `pulse`
/// (the Play button) minimizes the first card and brings it back.
struct LabMVWindow: View {
    let look: LabMVLook
    var pulse = ""
    @State private var minimized: Set<String> = []
    @State private var hidden: Set<String> = []
    @State private var flight: LabMVFlight?
    @State private var lastFlight: LabMVFlight?
    @State private var progress: CGFloat = 0
    @State private var frames: [String: CGRect] = [:]
    @State private var lastCard: [String: CGRect] = [:]
    @State private var lastBanner: [String: CGRect] = [:]

    private let servers = Array(LabTIServer.all.prefix(3))
    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var scale: Double { look.speed.scale }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, itemSize + railPad * 2 + SpacingTokens.sm + SpacingTokens.xxs1)
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1).zIndex(2)
            // Always mounted, so its progress is animated rather than inserted at its end value.
            if let shown = flight ?? lastFlight {
                LabMVMorph(progress: progress, server: .named(shown.id), flight: shown, look: look)
                    .opacity(flight == nil ? 0 : 1)
                    .zIndex(3)
            }
        }
        .coordinateSpace(name: "mv")
        .onPreferenceChange(LabMVFrames.self) { new in
            frames = new
            for (key, value) in new {
                if key.hasPrefix("card-") { lastCard[String(key.dropFirst(5))] = value }
                if key.hasPrefix("banner-") { lastBanner[String(key.dropFirst(7))] = value }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .onChange(of: pulse) { _, _ in play() }
    }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(servers.filter { !hidden.contains($0.id) }) { server in
                LabHCCard(server: server.server, look: LabHCLook(), rowLimit: 2, interactive: false, reportsBanner: true)
                    .opacity(flight?.id == server.id ? 0 : 1)
                    .overlay(alignment: .topTrailing) {
                        Color.clear.frame(width: SpacingTokens.xxxl * 3, height: SpacingTokens.xxxl - SpacingTokens.xs).contentShape(Rectangle())
                            .onTapGesture { minimize(server) }
                    }
                    .background(report("card-\(server.id)"))
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .padding(.trailing, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func report(_ id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: LabMVFrames.self, value: [id: proxy.frame(in: .named("mv"))])
        }
    }

    // MARK: Rail

    private var rail: some View {
        VStack(spacing: LayoutTokens.Rail.itemSpacing) {
            ForEach(servers) { server in
                let isMinimized = minimized.contains(server.id)
                Button { if isMinimized { restore(server) } } label: {
                    LabTIMark(server: server, style: .monogram, isSelected: false, isRing: isMinimized, size: itemSize)
                        // The flight is the item while it is on its way.
                        .opacity(flight?.id == server.id ? 0 : 1)
                }
                .buttonStyle(.plain)
                .background(report("item-\(server.id)"))
            }
            Image(systemName: "plus").font(.system(size: LayoutTokens.Rail.toolSymbolSize)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: itemSize, height: itemSize)
        }
        .padding(railPad)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Actions

    private func minimize(_ server: LabTIServer) {
        guard flight == nil, !minimized.contains(server.id),
              let from = frames["card-\(server.id)"], let banner = frames["banner-\(server.id)"], let to = frames["item-\(server.id)"] else { return }
        let next = LabMVFlight(id: server.id, isReturn: false, from: from, banner: banner, to: to)
        lastFlight = next
        flight = next
        if look.gap == .during { withAnimation(listAnimation) { _ = hidden.insert(server.id) } }
        // The flight starts the moment of the click: progress goes from its rest at 0 to 1 on one spring.
        withAnimation(look.animation, completionCriteria: .logicallyComplete) {
            progress = 1
        } completion: {
            land(server, isReturn: false)
        }
    }

    private func restore(_ server: LabTIServer) {
        guard flight == nil, minimized.contains(server.id) else { return }
        withAnimation(listAnimation) { _ = hidden.remove(server.id) }
        guard look.restore == .reverse, let from = lastCard[server.id], let banner = lastBanner[server.id], let to = frames["item-\(server.id)"] else {
            minimized.remove(server.id)
            progress = 0
            return
        }
        let next = LabMVFlight(id: server.id, isReturn: true, from: from, banner: banner, to: to)
        lastFlight = next
        flight = next
        withAnimation(look.animation, completionCriteria: .logicallyComplete) {
            progress = 0
        } completion: {
            land(server, isReturn: true)
        }
    }

    private var listAnimation: Animation { .smooth(duration: 0.4 * scale) }

    private func land(_ server: LabTIServer, isReturn: Bool) {
        flight = nil
        if isReturn {
            minimized.remove(server.id)
        } else {
            minimized.insert(server.id)
            if look.gap == .after { withAnimation(listAnimation) { _ = hidden.insert(server.id) } }
        }
    }

    /// Minimizes the first card, then brings it back.
    private func play() {
        guard let first = servers.first else { return }
        Task { @MainActor in
            if minimized.contains(first.id) { restore(first) } else { minimize(first) }
            try? await Task.sleep(for: .seconds(look.duration.seconds * scale + 1.3))
            if minimized.contains(first.id), flight == nil { restore(first) }
        }
    }
}

/// The animation in eight stills, from the card to the circle in its place: what the flight looks
/// like at 0, 12, 25, 40, 55, 70, 85 and 100%, with the chosen path and fold.
struct LabMVFilmstrip: View {
    let look: LabMVLook
    private let steps: [CGFloat] = [0, 0.12, 0.25, 0.4, 0.55, 0.7, 0.85, 1]

    var body: some View {
        let server = LabTIServer.named("prod")
        let from = CGRect(x: 56, y: 10, width: 236, height: 196)
        let banner = CGRect(x: 56, y: 10, width: 236, height: 92)
        let to = CGRect(x: 6, y: 12, width: 34, height: 34)
        let flight = LabMVFlight(id: server.id, isReturn: false, from: from, banner: banner, to: to)
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.xs, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.xs) {
                ForEach(steps, id: \.self) { step in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text("\(Int(step * 100))%").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        ZStack(alignment: .topLeading) {
                            Capsule().fill(Color.clear).glassEffect(.regular, in: .capsule)
                                .frame(width: 46, height: 170).offset(x: 1, y: 1)
                            LabMVMorph(progress: step, server: server, flight: flight, look: look)
                        }
                        .frame(width: 300, height: 214, alignment: .topLeading)
                        .background(ColorTokens.Workspace.canvas, in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
                    }
                }
            }
            .padding(SpacingTokens.sm)
        }
        .labScrollSizing()
        .background(ColorTokens.Workspace.canvas)
    }
}
