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
                level: .code, commit: "2776c002", date: "2026-09-30",
                note: "Read from MotionToken, SpacingToken, TypographyToken, AdaptiveColor, LayoutToken and the workspace settings. The principles are the design docs' rules; Echo has no code that checks them."),
            stageHeight: 480,
            behaviours: [
                .init(trigger: "Reduce Motion", result: "Every move (house spring, settle, expand, reveal, liquid stretch) becomes a 0.18s ease-in-out fade with no bounce; hover and press shorten to 0.1s; looping effects (the connecting pulse, shimmer) stop.", ),
                .init(trigger: "Reduce Transparency", result: "Echo has no code of its own for it: the system decides how Liquid Glass looks. Cards are opaque anyway."),
                .init(trigger: "Increase Contrast", result: "Colours made with the adaptive helper switch to their high-contrast values (the sidebar fills, the tab strip and similar); system colours follow the system."),
                .init(trigger: "Card Corners setting", result: "Every card takes 10, 12, 16 (default), 20 or 26pt from one environment value, workspaceCardCornerRadius."),
                .init(trigger: "Motion speed setting", result: "Default or Fast scales every duration by 1 or 0.7. Reduce Motion wins over it."),
            ],
            motions: [
                .init(name: "Standard (the house spring)", curve: "bouncy, extra bounce 0.08", duration: "0.45s", note: "selection, cards, panels"),
                .init(name: "Settle", curve: "smooth, no overshoot", duration: "0.45s", note: "moving to a resting place, such as hiding the tree"),
                .init(name: "Hover", curve: "ease out", duration: "0.12s"),
                .init(name: "Press", curve: "ease out", duration: "0.16s", note: "press and selection feedback"),
                .init(name: "Expand", curve: "ease in-out", duration: "0.22s", note: "folders in the tree"),
                .init(name: "Reveal", curve: "smooth", duration: "0.40s", note: "scrolling the tree to what you picked"),
                .init(name: "Liquid stretch: leading edge", curve: "spring, bounce 0.25", duration: "0.28s", note: "the rail selection races to its target"),
                .init(name: "Liquid stretch: trailing edge", curve: "spring, bounce 0.3, 0.06s later", duration: "0.55s"),
                .init(name: "Connecting pulse", curve: "ease in-out", duration: "0.7s half cycle", note: "down to 15% opacity and 90% size"),
            ],
            measurements: [
                .init(label: "Card corners", value: "16pt default", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Card shadow", value: "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard"),
                .init(label: "Standard text", value: "13pt", token: "TypographyTokens.standard"),
                .init(label: "Detail text", value: "11pt", token: "TypographyTokens.detail"),
                .init(label: "Type steps", value: "compact 9 · label 10 · detail 11 · caption2 12 · standard 13 · prominent 14pt, code 13pt monospaced", token: "TypographyTokens"),
                .init(label: "Spacing steps", value: "1 · 2 · 2.5 · 3 · 3.5 · 4 · 5 · 6 · 7 · 8 · 10 · 12 · 14 · 15 · 16 · 18 · 20 · 24 · 30 · 32 · 40 · 48 · 64pt", token: "SpacingTokens"),
                .init(label: "Form styles", value: "section title 13 bold · label and value 13 · description 11", token: "TypographyTokens.formSectionTitle / formLabel / formValue / formDescription"),
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
        },
        spec: FoundationsSpec.spec(stageHeight: 480) { FoundationsSpecimen() }
    )
}
