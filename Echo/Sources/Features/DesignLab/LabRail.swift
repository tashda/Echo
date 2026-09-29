#if DEBUG
import SwiftUI

enum LabRailSelection: String, CaseIterable, Identifiable {
    case disc = "White disc"
    case liquid = "Liquid stretch"
    case lens = "Glass lens"
    var id: String { rawValue }
}

enum LabRailIdentity: String, CaseIterable, Identifiable {
    case plain = "Plain"
    case colorOnSelection = "Colour on selection"
    var id: String { rawValue }
}

/// The two-pill rail: servers on top (hugging, scrolling once full), tools at the bottom.
struct LabRailView: View {
    var servers: [LabServer]
    @Binding var selectedID: String?
    var selection: LabRailSelection = .disc
    var identity: LabRailIdentity = .plain
    var speed: LabSpeed = .standard
    var onServerTap: (LabServer) -> Void = { _ in }

    static let itemSize: CGFloat = 34
    static let itemSpacing: CGFloat = 4
    static let pillPadding: CGFloat = 4
    static let width: CGFloat = itemSize + pillPadding * 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Top and bottom edge of the selection shape, animated separately for the liquid stretch.
    @State private var selectionTop: CGFloat = 0
    @State private var selectionBottom: CGFloat = LabRailView.itemSize

    var body: some View {
        VStack(spacing: 0) {
            serverPill
            Spacer(minLength: 12)
            toolPill
        }
        .frame(width: Self.width)
        .onAppear { snapSelection() }
        .onChange(of: selectedID) { oldID, newID in moveSelection(from: oldID, to: newID) }
        .onChange(of: servers.map(\.id)) { _, _ in snapSelection() }
    }

    // MARK: Servers

    private var contentHeight: CGFloat {
        let count = CGFloat(servers.count)
        return count * Self.itemSize + max(0, count - 1) * Self.itemSpacing + Self.pillPadding * 2
    }

    private var serverPill: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .top) {
                selectionShape
                VStack(spacing: Self.itemSpacing) {
                    ForEach(servers) { server in
                        serverItem(server)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            }
            .padding(Self.pillPadding)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: contentHeight)
        .glassEffect(.regular, in: .capsule)
        .animation(speed.spring(reduceMotion: reduceMotion), value: servers.map(\.id))
    }

    private func serverItem(_ server: LabServer) -> some View {
        let isSelected = server.id == selectedID
        return Button {
            selectedID = server.id
            onServerTap(server)
        } label: {
            Text(server.monogram)
                .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(monogramColor(server, isSelected: isSelected))
                .frame(width: Self.itemSize, height: Self.itemSize)
                .contentShape(Circle())
                .modifier(LabBreathing(isActive: server.isConnecting && !reduceMotion))
        }
        .buttonStyle(.plain)
        .help("\(server.name)\(server.isConnecting ? " · connecting" : "")")
    }

    private func monogramColor(_ server: LabServer, isSelected: Bool) -> Color {
        guard isSelected else { return .secondary }
        return identity == .colorOnSelection ? server.color : .accentColor
    }

    @ViewBuilder
    private var selectionShape: some View {
        if selectedID != nil {
            let height = max(Self.itemSize, selectionBottom - selectionTop)
            switch selection {
            case .disc, .liquid:
                Capsule()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.16), radius: 1.5, y: 0.5)
                    .frame(width: Self.itemSize, height: height)
                    .offset(y: selectionTop)
            case .lens:
                Capsule()
                    .fill(.clear)
                    .frame(width: Self.itemSize, height: height)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .offset(y: selectionTop)
            }
        }
    }

    private func y(for id: String?) -> CGFloat? {
        guard let id, let index = servers.firstIndex(where: { $0.id == id }) else { return nil }
        return CGFloat(index) * (Self.itemSize + Self.itemSpacing)
    }

    private func snapSelection() {
        guard let top = y(for: selectedID) else { return }
        selectionTop = top
        selectionBottom = top + Self.itemSize
    }

    private func moveSelection(from oldID: String?, to newID: String?) {
        guard let target = y(for: newID) else { return }
        let base = speed.spring(reduceMotion: reduceMotion)
        guard selection == .liquid, !reduceMotion, let origin = y(for: oldID), origin != target else {
            withAnimation(base) {
                selectionTop = target
                selectionBottom = target + Self.itemSize
            }
            return
        }
        // The leading edge races ahead and the trailing edge follows, so the shape stretches
        // toward the target like a drop of liquid, then settles back into a disc.
        let lead = Animation.spring(duration: 0.28 * speed.scale, bounce: 0.25)
        let trail = Animation.spring(duration: 0.55 * speed.scale, bounce: 0.3).delay(0.06 * speed.scale)
        if target > origin {
            withAnimation(lead) { selectionBottom = target + Self.itemSize }
            withAnimation(trail) { selectionTop = target }
        } else {
            withAnimation(lead) { selectionTop = target }
            withAnimation(trail) { selectionBottom = target + Self.itemSize }
        }
    }

    // MARK: Tools

    private var toolPill: some View {
        VStack(spacing: 2) {
            ForEach(["bookmark", "curlybraces", "clock", "clipboard"], id: \.self) { symbol in
                Button {} label: {
                    Image(systemName: symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: Self.itemSize, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Self.pillPadding)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Fades a connecting server's monogram in and out until it connects.
struct LabBreathing: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.phaseAnimator([1.0, 0.3]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.8) }
        } else {
            content
        }
    }
}

/// Rail playground: compare selection styles and identity, add or remove servers, set one connecting.
struct LabRailPlayground: View {
    @State private var servers = Array(LabServer.samples.prefix(3))
    @State private var selectedID: String? = "pg18"
    @State private var selection: LabRailSelection = .disc
    @State private var identity: LabRailIdentity = .plain
    @State private var speed: LabSpeed = .standard
    @State private var canvas: LabCanvas = .grey

    var body: some View {
        LabStage(title: "Server rail") {
            LabPicker(title: "Selection", selection: $selection, options: LabRailSelection.allCases)
            LabPicker(title: "Identity", selection: $identity, options: LabRailIdentity.allCases)
            LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
            LabPicker(title: "Canvas", selection: $canvas, options: LabCanvas.allCases)
        } content: {
            HStack(alignment: .top, spacing: 24) {
                LabRailView(servers: servers, selectedID: $selectedID, selection: selection, identity: identity, speed: speed)
                    .frame(height: 420)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Click servers to watch the selection move. Hover a server for its tooltip.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("Connect a server") { connect() }
                            .disabled(servers.count == LabServer.samples.count)
                        Button("Disconnect last") { disconnect() }
                            .disabled(servers.count <= 1)
                    }
                    Button("Jump first ↔ last") {
                        selectedID = selectedID == servers.first?.id ? servers.last?.id : servers.first?.id
                    }
                    Text("A connecting server breathes until it connects, then settles.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LabCanvasBackground(canvas: canvas))
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func connect() {
        guard let next = LabServer.samples.first(where: { sample in !servers.contains(where: { $0.id == sample.id }) }) else { return }
        var connecting = next
        connecting.isConnecting = true
        servers.append(connecting)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if let index = servers.firstIndex(where: { $0.id == next.id }) { servers[index].isConnecting = false }
        }
    }

    private func disconnect() {
        let removed = servers.removeLast()
        if selectedID == removed.id { selectedID = servers.last?.id }
    }
}

#Preview("Rail · selection, identity, status") {
    LabRailPlayground()
}
#endif
