import SwiftUI

/// The window as it is in Echo today: a canvas with the server rail, opaque cards, and glass
/// only on controls (decisions 2026-09-29, review rounds 3 to 9).
@MainActor
enum WindowArea {
    static let area = LabArea(
        id: "window",
        title: "Window and cards",
        symbol: "macwindow",
        summary: "A canvas holding the server rail, the tree, and opaque cards. Glass is only for controls.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Written from the decision log and LayoutTokens; the specimen is the rail with two stand-in cards."),
            stageHeight: 520,
            behaviours: [
                .init(trigger: "Click a server in the rail", result: "The tree jumps to that server; the rail marks the server whose rows are at the top while you scroll."),
                .init(trigger: "Click a server with the tree hidden", result: "A plain click peeks: the tree slides out over the cards, and a click away or Esc slides it back. ⌘-click or double-click reopens the tree for good (a setting changes this)."),
                .init(trigger: "Server connecting", result: "Its monogram breathes until it connects."),
                .init(trigger: "Connection lost", result: "The monogram dims to 40% and the tooltip says why."),
                .init(trigger: "Hover a server", result: "The system tooltip shows the name and host."),
                .init(trigger: "Click +", result: "Opens the connections menu; it is never selected."),
                .init(trigger: "No server and no tab", result: "The welcome sits on the canvas with no card: icon, Connect, Quick Connect, Manage, then the 5 latest connections."),
                .init(trigger: "Server active, no tab", result: "The server page: name, version, glass tool buttons with New Query first, and a databases card."),
                .init(trigger: "Nothing to show in the tree", result: "The tree hides and ⌃⌘S does nothing."),
            ],
            motions: [
                .init(name: "Rail selection", curve: "liquid stretch: the leading edge races, the trailing edge follows", duration: "0.28s and 0.55s", note: "echoMotion.liquidLead and liquidTrail"),
                .init(name: "Server pill grows and shrinks", curve: "house spring", duration: "0.45s"),
                .init(name: "Hide the tree", curve: "smooth, no overshoot", duration: "0.45s", note: "echoMotion.settle; the tree slides left behind the rail"),
                .init(name: "Show the tree", curve: "house spring", duration: "0.45s"),
                .init(name: "Connecting monogram", curve: "opacity breathing", duration: "0.7s half cycle", note: "echoMotion.pulseHalfPeriod; min opacity 15%"),
            ],
            measurements: [
                .init(label: "Card corners", value: "16pt (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Card shadow", value: "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard"),
                .init(label: "Rail item", value: "34pt (small and large are a setting)", token: "LabRailView.itemSize; RailItemSize.points"),
                .init(label: "Rail pill padding", value: "4pt", token: "LayoutTokens.Rail.pillPadding"),
                .init(label: "Selection disc inset", value: "3pt"),
                .init(label: "Tool button height", value: "30pt", token: "LayoutTokens.Rail.toolHeight"),
                .init(label: "Tree width", value: "260pt ideal, 200 to 480", token: "LayoutTokens.Workspace.treeIdealWidth / Min / Max"),
                .init(label: "Gap between panes", value: "4, 6 or 8pt (setting)", token: "Spacing Between Panes"),
            ],
            rules: [
                .init(text: "Cards are opaque, and glass never goes on them",
                      why: "The tree and editor are content. Glass over a flat canvas has nothing to refract and reads as a grey box.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "Card corners are 16pt",
                      why: "The macOS 27 window corner, measured from a screenshot; a Card Corners setting offers 10 to 26.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "A + ends the server pill",
                      why: "With one server the pill held a single item and read as a double border; connecting from the rail is also closer to the servers.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "The selection disc is inset 3pt",
                      why: "So a single server never looks like a pill inside a pill.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "Identity is a two-letter monogram in the server's colour",
                      why: "Colour dots and engine badges were rejected; the selected monogram takes its server's colour.",
                      rounds: ["decided.rail-servers"]),
                .init(text: "Welcome and server pages sit on the canvas, no card",
                      why: "Cards are only for content.",
                      rounds: ["decided.window-canvas-and-cards"]),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift",
                "Echo/Sources/Shared/DesignSystem/Components/WorkspaceCard.swift",
                "Packages/EchoDesignSystem/.../LayoutToken.swift (Workspace, Rail)",
            ]
        ) {
            WindowSpecimen()
        }
    )
}

private struct WindowSpecimen: View {
    @State private var selected: String? = LabServer.samples.first?.id
    @Environment(\.workspaceCardCornerRadius) private var corner

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            LabRailView(servers: LabServer.samples, selectedID: $selected, selection: .liquid, identity: .colorOnSelection)
            LabRound14TreeStub().frame(width: 220)
            VStack(spacing: SpacingTokens.sm) {
                card("Editor")
                card("Results")
            }
        }
        .padding(SpacingTokens.lg)
    }

    private func card(_ title: String) -> some View {
        Text(title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .workspaceCard()
    }
}
