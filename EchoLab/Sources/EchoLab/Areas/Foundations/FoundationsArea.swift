import SwiftUI

/// The rules every screen follows: principles, colour, type, spacing, cards and motion. These
/// are the visual guidelines, drawn from the shared tokens so they can't drift from Echo.
@MainActor
enum FoundationsArea {
    static let area = LabArea(
        id: "foundations",
        title: "Foundations",
        symbol: "paintpalette",
        summary: "How Echo looks and moves everywhere: native first, glass only on controls, every value from a token.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Drawn from the EchoDesignSystem tokens Echo itself uses."),
            stageHeight: 480,
            behaviours: [
                .init(trigger: "Reduce Motion", result: "Every move becomes a 0.18s fade with no bounce; looping effects stop."),
                .init(trigger: "Reduce Transparency", result: "Glass controls fall back to opaque fills; cards are opaque anyway."),
                .init(trigger: "Increase Contrast", result: "Sidebar fills strengthen (adaptive colours) and edges stay visible."),
                .init(trigger: "Card Corners setting", result: "Every card takes 10, 12, 16, 20 or 26pt from one environment value."),
                .init(trigger: "Motion speed setting", result: "Default or Fast (0.7×) scales every duration."),
            ],
            motions: [
                .init(name: "Standard (the house spring)", curve: "bouncy, extra bounce 0.08", duration: "0.45s", note: "selection, cards, panels"),
                .init(name: "Settle", curve: "smooth, no overshoot", duration: "0.45s", note: "moving to a resting place, such as hiding the tree"),
                .init(name: "Hover", curve: "ease out", duration: "0.12s"),
                .init(name: "Press", curve: "ease out", duration: "0.16s"),
                .init(name: "Expand", curve: "ease in-out", duration: "0.22s", note: "folders in the tree"),
                .init(name: "Reveal", curve: "smooth", duration: "0.40s"),
            ],
            measurements: [
                .init(label: "Card corners", value: "16pt default", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Card shadow", value: "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard"),
                .init(label: "Standard text", value: "13pt", token: "TypographyTokens.standard"),
                .init(label: "Detail text", value: "11pt", token: "TypographyTokens.detail"),
                .init(label: "Spacing steps", value: "2 · 4 · 6 · 8 · 10 · 12 · 16 · 24", token: "SpacingTokens"),
            ],
            rules: [
                .init(text: "Native first", why: "Use the system control, material or behaviour when one exists; build our own only when it can't do the job."),
                .init(text: "Glass is for controls, never content", why: "Rail, toolbar, toasts and floating cards use glass. The tree, editor, results and inspector are opaque."),
                .init(text: "No glass on glass", why: "Selection inside a glass pill is a fill, not a second layer."),
                .init(text: "One structure everywhere", why: "The rail, tree and cards stay put whether the tree is shown or hidden; only the cards move."),
                .init(text: "Motion explains change", why: "Every animation shows where something came from or went. Pulsing is only for in-progress states."),
                .init(text: "Everything through tokens", why: "No literal numbers or colours in views; sizes, radii, spacing, colours and animations come from the token files."),
                .init(text: "Settings where taste differs", why: "Rail size, tree density, icon colour, pane gutter, gutter style, mono result cells and motion speed are settings with chosen defaults."),
                .init(text: "Keep what works", why: "The tab strip, result grid, tab overview and Run button are refined in place, not replaced."),
                .init(text: "Safari is the reference for tabs", why: "Tabs look and behave like Safari's."),
                .init(text: "Accessibility is not optional", why: "Reduce Motion, Reduce Transparency and Increase Contrast must all look right; every control has a label."),
            ],
            code: [
                "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/",
                "Design/01-principles.md · 03-materials.md · 04-motion.md · 06-tokens.md",
            ]
        ) {
            FoundationsSpecimen()
        }
    )
}
