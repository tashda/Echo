import SwiftUI

/// Round 40 · Clicking a server while the tree is hidden. Echo today (WorkspaceShell,
/// ServerRailClick, AppState.peekedServerID): with the tree hidden (⌃⌘S), a plain click on a server
/// "peeks": the tree slides out on glass over the cards, without moving them, until a click outside
/// or Esc; ⌘-click or a double-click shows the tree for good. The owner wants a click to open the
/// tree with that server selected.
///
/// Accepted 2026-10-01: RC1, OM0, SM1 (the owner's pick over the flash) and TV0; the owner then
/// chose to remove the peek and its setting too. Built into Echo as WIN-3.5 (WIN-3.3 retired).
@MainActor
enum RailClickHiddenTreeRound {
    enum Click: String, CaseIterable {
        case peek = "RC0 · Peek on glass over the cards (today)"
        case open = "RC1 · Open the tree, scrolled to the server and its card selected"
        case openOptionPeek = "RC2 · RC1, and ⌥-click still peeks"

        var summary: String {
            switch self {
            case .peek: "The tree floats over your work and disappears when you click elsewhere."
            case .open: "The cards make room and the tree stays open; hide it again with ⌃⌘S or the toolbar button."
            case .openOptionPeek: "For a quick look without moving the cards; most people would never find it."
            }
        }
    }

    enum Motion: String, CaseIterable {
        case together = "OM0 · The tree slides in while it scrolls to the server"
        case thenScroll = "OM1 · The tree slides in, then scrolls to the server"
    }

    enum Mark: String, CaseIterable {
        case flash = "SM0 · The server's card flashes its selection once"
        case none = "SM1 · Nothing more: the rail shows which server it is"
    }

    static let spec = RoundSpec(
        controls: [
            .of("click", "A click", Click.self, default: .open,
                question: "Hide the tree, then click each server in the rail. What should a click do?",
                recommend: .open,
                why: "You asked for it: the tree with the server ready to use. One behaviour for a click, hidden or shown, is easier than a peek that vanishes; RC2 keeps the peek for anyone who liked it, at the cost of a modifier nobody discovers.",
                summary: \.summary),
            .of("motion", "Motion", Motion.self, default: .together,
                question: "Watch the tree come in. Should it scroll while it slides, or after?",
                recommend: .together,
                why: "One movement ending on the server reads as 'here it is'; slide-then-scroll is two motions and takes twice as long."),
            .of("mark", "Arrival", Mark.self, default: .none,
                question: "Once the server is in view, should its card say so?",
                recommend: .flash,
                why: "With three cards in the column, a brief flash (the selection fill fading in and out once) tells your eye which card the click went to; the rail alone is 300pt away."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Click a server in the rail: the tree peeks over the cards.", isEchoToday: true,
                  isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabRCStage(click: .peek, motion: .together, mark: .none)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click a server; ⌃⌘S is the Hide button.",
                  isWide: true, designWidth: 760, designHeight: 440) { values in
                LabRCStage(click: Click(rawValue: values["click"]) ?? .open, motion: Motion(rawValue: values["motion"]) ?? .together,
                           mark: Mark(rawValue: values["mark"]) ?? .flash)
            },
        ],
        questions: [
            .init(id: "visible", title: "With the tree showing",
                  question: "And when the tree is already showing, a click on a server…",
                  choices: [.init(id: "scroll", name: "TV0 · Scrolls the tree to its card (today)"), .init(id: "scrollFlash", name: "TV1 · Scrolls and flashes its card, as above")],
                  recommended: "scrollFlash",
                  why: "The same arrival either way, so a click on a server always ends the same."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["click": Click.open.rawValue, "motion": Motion.together.rawValue, "mark": Mark.flash.rawValue], isRecommended: true)]
    )
}

/// A window with the tree hidden: the rail, the content card, and the tree that peeks or opens.
private struct LabRCStage: View {
    let click: RailClickHiddenTreeRound.Click
    let motion: RailClickHiddenTreeRound.Motion
    let mark: RailClickHiddenTreeRound.Mark
    @State private var treeShown = false
    @State private var peeking = false
    @State private var target: String?
    @State private var flash = false
    @Environment(\.echoMotion) private var echoMotion

    private let servers: [LabSHServer] = [.test, .development, .production]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Button(treeShown ? "Hide the tree (⌃⌘S)" : "Show the tree (⌃⌘S)") {
                withAnimation(echoMotion.standard) { treeShown.toggle(); peeking = false }
            }
            .controlSize(.small)
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                rail
                ZStack(alignment: .topLeading) {
                    HStack(spacing: SpacingTokens.xs) {
                        if treeShown { column.frame(width: 230).transition(.move(edge: .leading).combined(with: .opacity)) }
                        LabWKEditor().workspaceCard()
                    }
                    if peeking {
                        column.frame(width: 230)
                            .padding(SpacingTokens.xs)
                            .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md2))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .onTapGesture { if peeking { withAnimation(echoMotion.standard) { peeking = false } } }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
        .clipped()
    }

    private var rail: some View {
        VStack(spacing: SpacingTokens.xs) {
            ForEach(servers) { server in
                Text(server.monogram).font(TypographyTokens.caption2.weight(.bold))
                    .foregroundStyle(target == server.id ? server.color : ColorTokens.Text.secondary)
                    .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                    .background { if target == server.id { Circle().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection) } }
                    .onTapGesture { tapped(server.id) }
            }
        }
        .padding(SpacingTokens.xxs)
        .glassEffect(.regular, in: .capsule)
    }

    private var column: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: SpacingTokens.xs) {
                    ForEach(servers) { server in
                        LabSHCard(server: server, look: .today, selectedRow: nil)
                            .overlay {
                                if flash, target == server.id {
                                    RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
                                        .fill(ColorTokens.accent.opacity(0.12)).allowsHitTesting(false)
                                }
                            }
                            .id(server.id)
                    }
                }
                .padding(SpacingTokens.xxs)
            }
            .onChange(of: target) { _, id in
                guard let id else { return }
                let delay = motion == .thenScroll && click != .peek ? 0.35 : 0
                Task {
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(echoMotion.standard) { proxy.scrollTo(id, anchor: .top) }
                    guard mark == .flash else { return }
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(echoMotion.hover) { flash = true }
                    try? await Task.sleep(for: .seconds(0.45))
                    withAnimation(echoMotion.settle) { flash = false }
                }
            }
        }
    }

    private func tapped(_ id: String) {
        let isOption = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        withAnimation(echoMotion.standard) {
            if treeShown { target = id; return }
            switch click {
            case .peek: peeking = true
            case .open: treeShown = true
            case .openOptionPeek: if isOption { peeking = true } else { treeShown = true }
            }
            target = id
        }
    }
}
