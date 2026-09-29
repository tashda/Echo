#if DEBUG
import AppKit
import SwiftUI

enum LabCorner: String, CaseIterable, Identifiable {
    case concentric = "Concentric with window"
    case r12 = "12pt"
    case r16 = "16pt"
    var id: String { rawValue }
}

enum LabGutter: String, CaseIterable, Identifiable {
    case four = "4pt"
    case six = "6pt"
    case eight = "8pt"
    var id: String { rawValue }
    var value: CGFloat { self == .four ? 4 : self == .six ? 6 : 8 }
}

enum LabTreeHide: String, CaseIterable, Identifiable {
    case shrink = "Tree shrinks into rail"
    case over = "Cards slide over"
    var id: String { rawValue }
}

enum LabServerClick: String, CaseIterable, Identifiable {
    case peek = "Peek"
    case reopen = "Reopen tree"
    case split = "Peek · ⌘-click reopens"
    var id: String { rawValue }
}

enum LabTabPlace: String, CaseIterable, Identifiable {
    case canvas = "Tabs on canvas"
    case card = "Tabs in card"
    var id: String { rawValue }
}

/// The whole canvas-and-cards window: rail, tree, tab strip, editor and results cards. Every
/// open layout choice is a control above it.
struct LabWindowPlayground: View {
    @State private var canvas: LabCanvas = .grey
    @State private var corner: LabCorner = .concentric
    @State private var shadow: LabCardShadow = .lift
    @State private var gutter: LabGutter = .eight
    @State private var hideStyle: LabTreeHide = .shrink
    @State private var serverClick: LabServerClick = .split
    @State private var tabPlace: LabTabPlace = .canvas
    @State private var speed: LabSpeed = .standard

    @State private var isTreeVisible = true
    @State private var peekedServer: LabServer?
    @State private var selectedServerID: String? = "pg18"
    @State private var showsResults = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let windowRadius: CGFloat = 20
    private let treeWidth: CGFloat = 260

    var body: some View {
        LabStage(title: "Window · canvas and cards") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    LabPicker(title: "Canvas", selection: $canvas, options: LabCanvas.allCases)
                    LabPicker(title: "Corners", selection: $corner, options: LabCorner.allCases)
                    LabPicker(title: "Shadow", selection: $shadow, options: LabCardShadow.allCases)
                    LabPicker(title: "Gutter", selection: $gutter, options: LabGutter.allCases)
                }
                HStack(spacing: 14) {
                    LabPicker(title: "Hide tree", selection: $hideStyle, options: LabTreeHide.allCases)
                    LabPicker(title: "Server click", selection: $serverClick, options: LabServerClick.allCases)
                    LabPicker(title: "Tabs", selection: $tabPlace, options: LabTabPlace.allCases)
                    LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
                }
                HStack(spacing: 10) {
                    Button(isTreeVisible ? "Hide tree" : "Show tree") { toggleTree() }
                        .keyboardShortcut("s", modifiers: [.command, .control])
                    Button(showsResults ? "Close results" : "Run query") {
                        withAnimation(speed.spring(reduceMotion: reduceMotion)) { showsResults.toggle() }
                    }
                }
            }
        } content: {
            window
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .frame(width: 1180, height: 820)
    }

    // MARK: Window

    private var window: some View {
        VStack(spacing: 0) {
            titlebar
            workspace
        }
        .frame(width: 1080, height: 640)
        .background(LabCanvasBackground(canvas: canvas))
        .clipShape(.rect(cornerRadius: windowRadius))
        .containerShape(.rect(cornerRadius: windowRadius))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
    }

    private var titlebar: some View {
        HStack(spacing: 8) {
            ForEach([Color.red, .yellow, .green], id: \.self) { color in
                Circle().fill(color.opacity(0.85)).frame(width: 12, height: 12)
            }
            Spacer().frame(width: 12)
            toolbarGroup(["folder", "clock", "bolt"])
            Spacer()
            Label("Run", systemImage: "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .glassEffect(.regular.tint(.accentColor), in: .capsule)
                .foregroundStyle(.white)
            toolbarGroup(["sparkles", "exclamationmark.triangle", "text.book.closed"])
            toolbarGroup(["arrow.clockwise"])
            toolbarGroup(["sidebar.right"])
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private func toolbarGroup(_ symbols: [String]) -> some View {
        HStack(spacing: 2) {
            ForEach(symbols, id: \.self) { symbol in
                Image(systemName: symbol).font(.system(size: 13)).frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular, in: .capsule)
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: gutter.value) {
            LabRailView(
                servers: Array(LabServer.samples.prefix(3)),
                selectedID: $selectedServerID,
                selection: .disc,
                speed: speed,
                onServerTap: handleServerTap
            )
            .padding(.leading, gutter.value)

            ZStack(alignment: .topLeading) {
                treeLayer
                content
                    .padding(.leading, contentLeadingInset)
                if let peekedServer {
                    peek(peekedServer)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .padding([.trailing, .bottom], gutter.value)
        .padding(.top, 2)
    }

    /// With "cards slide over", the tree stays laid out and the cards cover it.
    private var contentLeadingInset: CGFloat {
        isTreeVisible ? treeWidth + gutter.value : 0
    }

    @ViewBuilder
    private var treeLayer: some View {
        switch hideStyle {
        case .shrink:
            if isTreeVisible {
                LabTreeView()
                    .frame(width: treeWidth)
                    .transition(.scale(scale: 0.55, anchor: .leading).combined(with: .opacity))
            }
        case .over:
            LabTreeView()
                .frame(width: treeWidth)
                .opacity(isTreeVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.2 * speed.scale).delay(isTreeVisible ? 0 : 0.15 * speed.scale), value: isTreeVisible)
        }
    }

    private var content: some View {
        VStack(spacing: gutter.value) {
            if tabPlace == .canvas { tabStrip }
            card {
                VStack(alignment: .leading, spacing: 0) {
                    if tabPlace == .card {
                        tabStrip.padding(8)
                    }
                    LabEditorText()
                }
            }
            if showsResults {
                card { LabResultsGridMock() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var tabStrip: some View {
        HStack(spacing: 2) {
            tab("salary · employees", isActive: true, isRunning: true)
            tab("Query 2", isActive: false, isRunning: false)
            tab("lego_sets", isActive: false, isRunning: false)
        }
        .padding(2)
        .background(Color.primary.opacity(0.07), in: .capsule)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tab(_ title: String, isActive: Bool, isRunning: Bool) -> some View {
        HStack(spacing: 6) {
            if isRunning { ProgressView().controlSize(.mini) }
            Text(title).font(.system(size: 11, weight: isActive ? .medium : .regular)).lineLimit(1)
            if isRunning {
                Text("0:42").font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Color.accentColor)
            }
        }
        .foregroundStyle(isActive ? .primary : .secondary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .background {
            if isActive {
                Capsule().fill(Color(nsColor: .textBackgroundColor)).shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
            }
        }
    }

    // MARK: Cards

    private func card<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor), in: cardShape)
            .overlay(cardShape.stroke(Color(nsColor: .separatorColor).opacity(shadow == .hairline ? 0.9 : 0.4), lineWidth: 0.5))
            .clipShape(cardShape)
            .shadow(color: .black.opacity(shadow == .lift ? 0.12 : 0.04), radius: shadow == .lift ? 10 : 1, y: shadow == .lift ? 4 : 0.5)
    }

    private var cardShape: AnyShape {
        switch corner {
        case .concentric: AnyShape(ConcentricRectangle())
        case .r12: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .r16: AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Behaviour

    private func toggleTree() {
        peekedServer = nil
        withAnimation(speed.spring(reduceMotion: reduceMotion)) { isTreeVisible.toggle() }
    }

    private func handleServerTap(_ server: LabServer) {
        guard !isTreeVisible else { return }
        let commandHeld = NSEvent.modifierFlags.contains(.command)
        switch serverClick {
        case .reopen:
            toggleTree()
        case .peek:
            togglePeek(server)
        case .split:
            commandHeld ? toggleTree() : togglePeek(server)
        }
    }

    private func togglePeek(_ server: LabServer) {
        withAnimation(speed.spring(reduceMotion: reduceMotion)) {
            peekedServer = peekedServer?.id == server.id ? nil : server
        }
    }

    /// The tree for one server, sliding out over the cards. A click outside closes it.
    private func peek(_ server: LabServer) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .onTapGesture { togglePeek(server) }
            LabTreeView(servers: [server])
                .frame(width: treeWidth, height: 420)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        }
    }
}

#Preview("Window · canvas, cards, tree hide, server click") {
    LabWindowPlayground()
}
#endif
