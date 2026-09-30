import SwiftUI

/// The rules every screen follows, by piece, each with a stable ID (`FND-3.2`). Values come from
/// the EchoDesignSystem tokens.
@MainActor
enum FoundationsSpec {
    private static let tokens = "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "FND", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static func rule(_ number: String, _ name: String, _ why: String) -> SpecElement {
        SpecElement(number: number, name: name, summary: why, groups: [.behaviour(.row("Rule", name), .row("Why", why))], files: ["Design/01-principles.md"])
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Principles", summary: "What every screen follows.", elements: [
            rule("1.1", "Native first", "Use the system control, material or behaviour when one exists; build our own only when it can't do the job."),
            rule("1.2", "One structure everywhere", "The rail, tree and cards stay put whether the tree is shown or hidden; only the cards move."),
            rule("1.3", "Motion explains change", "Every animation shows where something came from or went. Pulsing is only for in-progress states."),
            rule("1.4", "Everything through tokens", "No literal numbers or colours in views; sizes, radii, spacing, colours and animations come from the token files."),
            rule("1.5", "Settings where taste differs", "Rail size, tree density, icon colour, pane gutter, gutter style, mono result cells and motion speed are settings with chosen defaults."),
            rule("1.6", "Keep what works", "The tab strip, result grid, tab overview and Run button are refined in place, not replaced."),
            rule("1.7", "Safari is the reference for tabs", "Tabs look and behave like Safari's."),
        ]),
        SpecPart(number: "2", name: "Materials", summary: "Where glass goes and where it doesn't.", elements: [
            SpecElement(number: "2.1", name: "Glass is for controls", summary: "Rail, toolbar, toasts and floating cards use glass. The tree, editor, results and inspector are opaque.", groups: [
                .material(.row("Glass", "controls, never content"), .row("Opaque", "tree, editor, results, inspector")),
            ], files: ["Design/03-materials.md"]),
            SpecElement(number: "2.2", name: "No glass on glass", summary: "Selection inside a glass pill is a fill, not a second layer.", groups: [
                .material(.row("Selection in a pill", "a fill")),
            ], files: ["Design/03-materials.md"]),
            SpecElement(number: "2.3", name: "Card", summary: "The one card look.", groups: [
                .material(.row("Corner", "16pt default (setting: 10, 12, 16, 20 or 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                          .row("Edge", "0.5pt, 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                          .row("Shadow", "black 12%, blur 10, y 4", token: "ShadowTokens.workspaceCard")),
            ], files: [tokens + "LayoutToken.swift"]),
        ]),
        SpecPart(number: "3", name: "Motion", summary: "Six named animations; every move uses one.", elements: [
            SpecElement(number: "3.1", name: "Standard (the house spring)", summary: "Selection, cards, panels.", groups: [
                .motion(.row("Curve", "bouncy, extra bounce 0.08"), .row("Duration", "0.45s"), .row("Token", "echoMotion.standard")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.2", name: "Settle", summary: "Moving to a resting place, such as hiding the tree.", groups: [
                .motion(.row("Curve", "smooth, no overshoot"), .row("Duration", "0.45s"), .row("Token", "echoMotion.settle")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.3", name: "Hover", summary: "A fill or tint under the pointer.", groups: [
                .motion(.row("Curve", "ease out"), .row("Duration", "0.12s"), .row("Token", "echoMotion.hover")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.4", name: "Press", summary: "A control pressed.", groups: [
                .motion(.row("Curve", "ease out"), .row("Duration", "0.16s")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.5", name: "Expand", summary: "Folders in the tree.", groups: [
                .motion(.row("Curve", "ease in-out"), .row("Duration", "0.22s"), .row("Token", "echoMotion.expand")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.6", name: "Reveal", summary: "Scrolling to something you picked.", groups: [
                .motion(.row("Curve", "smooth"), .row("Duration", "0.40s"), .row("Token", "echoMotion.reveal")),
            ], files: [tokens + "MotionToken.swift"]),
            SpecElement(number: "3.7", name: "Motion speed", summary: "A setting: Default or Fast.", groups: [
                .behaviour(.row("Fast", "scales every duration to 0.7×")),
            ]),
        ]),
        SpecPart(number: "4", name: "Type and spacing", summary: "Sizes come from tokens.", elements: [
            SpecElement(number: "4.1", name: "Standard text", summary: "13pt, for labels and body.", groups: [.type(.row("Size", "13pt", token: "TypographyTokens.standard"))], files: [tokens + "TypographyToken.swift"]),
            SpecElement(number: "4.2", name: "Detail text", summary: "11pt, for secondary information.", groups: [.type(.row("Size", "11pt", token: "TypographyTokens.detail"))], files: [tokens + "TypographyToken.swift"]),
            SpecElement(number: "4.3", name: "Spacing steps", summary: "The only spacings views may use.", groups: [
                .layout(.row("Steps", "2 · 4 · 6 · 8 · 10 · 12 · 16 · 24", token: "SpacingTokens")),
            ], files: [tokens + "SpacingToken.swift"]),
        ]),
        SpecPart(number: "5", name: "Accessibility", summary: "Every setting looks right and every control has a label.", elements: [
            SpecElement(number: "5.1", name: "Reduce Motion", summary: "Every move becomes a fade; loops stop.", groups: [
                .behaviour(.row("Moves", "a 0.18s fade with no bounce"), .row("Looping effects", "stop")),
            ], files: ["Design/04-motion.md"]),
            SpecElement(number: "5.2", name: "Reduce Transparency", summary: "Glass falls back to opaque fills.", groups: [
                .behaviour(.row("Glass controls", "opaque fills"), .row("Cards", "opaque already")),
            ], files: ["Design/03-materials.md"]),
            SpecElement(number: "5.3", name: "Increase Contrast", summary: "Fills strengthen and edges stay visible.", groups: [
                .behaviour(.row("Sidebar fills", "strengthen (adaptive colours)"), .row("Edges", "stay visible")),
            ], files: ["Design/03-materials.md"]),
            rule("5.4", "Accessibility is not optional", "Reduce Motion, Reduce Transparency and Increase Contrast must all look right; every control has a label."),
        ]),
    ]
}
