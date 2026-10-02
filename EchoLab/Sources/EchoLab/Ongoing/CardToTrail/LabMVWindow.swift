import SwiftUI

/// The trail and three server cards, enough of Echo's window to feel a card going into the trail.
/// Click a card's header to minimize it; click its dashed-ring item to bring it back. `pulse`
/// (the Play button) minimizes the first card and brings it back.
struct LabMVWindow: View {
    let look: LabMVLook
    var pulse = ""
    @State private var minimized: Set<String> = []
    @State private var hidden: Set<String> = []
    @State private var ringed: Set<String> = []
    @State private var flight: LabMVFlight?
    @State private var frames: [String: CGRect] = [:]
    @State private var lastCard: [String: CGRect] = [:]
    @State private var popped: String?
    @State private var glowing: String?

    private let servers = Array(LabTIServer.all.prefix(3))
    private var itemSize: CGFloat { SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro }
    private var railPad: CGFloat { LayoutTokens.Rail.pillPadding }
    private var scale: Double { look.speed.scale }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tree.padding(.leading, itemSize + railPad * 2 + SpacingTokens.sm + SpacingTokens.xxs1)
            if let flight, look.motion == .slide { token(flight) }
            rail.padding(.leading, SpacingTokens.xxs1).padding(.top, SpacingTokens.xxs1).zIndex(2)
            if let flight, look.motion != .slide { token(flight).zIndex(3) }
        }
        .coordinateSpace(name: "mv")
        .onPreferenceChange(LabMVFrames.self) { new in
            frames = new
            for (key, value) in new where key.hasPrefix("card-") { lastCard[key] = value }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .onChange(of: pulse) { _, _ in play() }
        .task(id: flight) { await land() }
    }

    // MARK: Tree

    private var tree: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(servers.filter { !hidden.contains($0.id) }) { server in
                LabSHCard(server: server.server, look: .today, rowLimit: 2, selectedRow: nil)
                    .opacity(flight?.id == server.id ? 0 : 1)
                    .overlay(alignment: .topTrailing) {
                        Color.clear.frame(width: SpacingTokens.xl2, height: SpacingTokens.xl).contentShape(Rectangle())
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
                Button { if minimized.contains(server.id) { restore(server) } } label: {
                    LabTIMark(server: server, style: .monogram, isSelected: false, size: itemSize)
                        .overlay { ring(for: server) }
                        .scaleEffect(popped == server.id ? 1.28 : 1)
                        .shadow(color: glowing == server.id ? server.server.color.opacity(0.9) : .clear, radius: SpacingTokens.xs2)
                        .opacity(minimized.contains(server.id) ? 0.75 : 1)
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

    /// The dashed ring of a minimized server; with RC2 and RC4 it draws itself.
    @ViewBuilder
    private func ring(for server: LabTIServer) -> some View {
        if minimized.contains(server.id) || ringed.contains(server.id) {
            let drawn = ringed.contains(server.id)
            Circle()
                .trim(from: 0, to: look.receive.drawsRing ? (drawn ? 1 : 0.001) : 1)
                .stroke(server.server.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .rotationEffect(.degrees(-90))
                .padding(SpacingTokens.micro)
        }
    }

    // MARK: Token

    private func token(_ flight: LabMVFlight) -> some View {
        TimelineView(.animation) { context in
            let raw = LabMVEase.clamp(context.date.timeIntervalSince(flight.start) / flight.duration)
            let progress = flight.isReturn ? 1 - (look.restore == .grow ? LabMVEase.overshoot(raw) : raw) : raw
            LabMVToken(server: .named(flight.id), pose: .make(look.motion, p: progress, from: flight.from, to: flight.to), from: flight.from)
        }
    }

    // MARK: Actions

    private func minimize(_ server: LabTIServer) {
        guard flight == nil, !minimized.contains(server.id),
              let from = frames["card-\(server.id)"], let to = frames["item-\(server.id)"] else { return }
        flight = LabMVFlight(id: server.id, isReturn: false, start: .now, duration: look.motion.duration * scale, from: from, to: to)
        if look.gap == .during { withAnimation(listAnimation) { _ = hidden.insert(server.id) } }
    }

    private func restore(_ server: LabTIServer) {
        guard flight == nil, minimized.contains(server.id) else { return }
        withAnimation(.easeOut(duration: 0.25)) { _ = ringed.remove(server.id) }
        withAnimation(listAnimation) { _ = hidden.remove(server.id) }
        guard look.restore != .simple, let from = lastCard["card-\(server.id)"], let to = frames["item-\(server.id)"] else {
            minimized.remove(server.id)
            return
        }
        flight = LabMVFlight(id: server.id, isReturn: true, start: .now, duration: look.motion.duration * scale * (look.restore == .grow ? 1.1 : 1),
                             from: from, to: to)
    }

    private var listAnimation: Animation { .smooth(duration: 0.35 * scale) }

    /// Waits for the flight to end, then settles the state and lets the trail item answer.
    private func land() async {
        guard let flight else { return }
        try? await Task.sleep(for: .seconds(flight.duration))
        guard !Task.isCancelled else { return }
        self.flight = nil
        if flight.isReturn {
            minimized.remove(flight.id)
            return
        }
        minimized.insert(flight.id)
        if look.gap == .after { withAnimation(listAnimation) { _ = hidden.insert(flight.id) } }
        let drawsRing = look.receive.drawsRing
        withAnimation(drawsRing ? .easeOut(duration: 0.5 * scale) : nil) { _ = ringed.insert(flight.id) }
        if look.receive.pops {
            withAnimation(.bouncy(duration: 0.3 * scale, extraBounce: 0.3)) { popped = flight.id }
            try? await Task.sleep(for: .seconds(0.16 * scale))
            withAnimation(.bouncy(duration: 0.3 * scale, extraBounce: 0.2)) { popped = nil }
        }
        if look.receive.glows {
            withAnimation(.easeOut(duration: 0.15)) { glowing = flight.id }
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(.easeIn(duration: 0.6 * scale)) { glowing = nil }
        }
    }

    /// Minimizes the first card, then brings it back.
    private func play() {
        guard let first = servers.first else { return }
        Task { @MainActor in
            if minimized.contains(first.id) { restore(first) } else { minimize(first) }
            try? await Task.sleep(for: .seconds(look.motion.duration * scale + 1.2))
            if minimized.contains(first.id) { restore(first) }
        }
    }
}

/// Every motion in a window of its own; Play runs them all.
struct LabMVGallery: View {
    let look: LabMVLook
    let pulse: String

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm, alignment: .top), count: 2),
                      alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabMVMotion.allCases, id: \.self) { motion in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(motion.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        LabMVWindow(look: look.with(motion: motion), pulse: pulse)
                            .frame(height: SpacingTokens.xxxl * 5.6)
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
