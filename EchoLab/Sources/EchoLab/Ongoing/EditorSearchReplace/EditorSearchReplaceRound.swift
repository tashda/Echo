import SwiftUI

/// Round 28.13 · Editor: search and replace (asked in the owner's notes on 28.12: FB5's glass,
/// RP1's chevron; refine how the replacement shows while typing, the Replace row's opening, and
/// the shortcuts). Echo today: NSTextView's find bar; Replace is its second row, opened from the
/// bar's menu or ⌥⌘F (the system's Find and Replace), with no preview of the change.
@MainActor
enum EditorSearchReplaceRound {
    static let spec = RoundSpec(
        controls: [
            .of("replacePreview", "The replacement while you type", LabQEReplacePreview.self, default: .inlineDiff,
                question: "Open Replace in the Proposal (chevron, or Find and Replace on the left), type a replacement, and compare All previews. How should the editor show what will change?",
                recommend: .inlineDiff,
                why: "You loved seeing the replacement in the editor; reading it as a diff on its own line (old struck through, new beside it) says exactly what changes without covering the line above, which PV1's tags did. PV4 (the current match only) is the calm runner-up for long scripts; PV3 hides the old word, so you can't check it; the gutter marks (PV5) help with Replace All in a long script.",
                summary: \.summary),
            .of("replaceOpening", "Opening Replace", LabQEReplaceOpening.self, default: .grow,
                question: "Click the chevron in the Proposal a few times with each choice. How should the Replace row open?",
                recommend: .grow,
                why: "You asked for it to expand: the capsule growing with the house spring keeps one glass shape and the row fading in, exactly like FB5 itself. The melting glass row (AN3) is the most macOS 26 and a close second, but two shapes for one bar read as two controls; the bounce is playful for something you open dozens of times a day.",
                summary: \.summary),
            .of("findShortcuts", "Shortcuts", LabQEFindShortcuts.self, default: .macOS,
                question: "Look at the Edit › Find menu exhibit. Which keys should open Find, and Find and Replace?",
                recommend: .macOS,
                why: "⌥⌘F is Find and Replace in every Mac app, so it works the first time; it is free in Echo (⌥⌘F isn't Search: Search is ⌘K). Pressing ⌘F twice is clever but hidden; ⇧⌘R is an invention; ⌃H is a Windows habit that Mac users don't expect.",
                summary: \.summary),
        ],
        actions: [
            .init(id: "find", title: "Find (⌘F)", symbol: "magnifyingglass") { _ in LabQESearchCommands.shared.openFind += 1 },
            .init(id: "replace", title: "Find and Replace", symbol: "arrow.2.squarepath") { _ in LabQESearchCommands.shared.openReplace += 1 },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The system's find bar with its Replace row; nothing shows what will change.", isEchoToday: true,
                  designWidth: LabQERound.width, designHeight: LabQERound.height) { _ in
                LabQEEditor(style: .today, scene: LabQESceneChoice.replace.scene)
            },
            .init(id: "proposal", title: "Proposal", summary: "Working: type, open Replace with the chevron, Replace (or Return), Replace All; ↺ resets.",
                  designWidth: LabQESearchReplacePlayground.width, designHeight: LabQESearchReplacePlayground.height) { values in
                LabQESearchReplacePlayground(preview: LabQEReplacePreview(rawValue: values["replacePreview"]) ?? .inlineDiff,
                                             opening: LabQEReplaceOpening(rawValue: values["replaceOpening"]) ?? .grow,
                                             shortcuts: LabQEFindShortcuts(rawValue: values["findShortcuts"]) ?? .macOS)
            },
            .init(id: "previews", title: "All previews", summary: "Every preview, replacing “orders” with “orders_2026”; the first match is the current one.",
                  designWidth: 700, designHeight: 640) { _ in
                LabQEPreviewGrid()
            },
            .init(id: "menu", title: "Edit › Find", summary: "The menu with the chosen shortcuts.", designWidth: 340, designHeight: 240) { values in
                LabQEFindMenu(shortcuts: LabQEFindShortcuts(rawValue: values["findShortcuts"]) ?? .macOS)
            },
        ],
        questions: [
            .init(id: "returnKey", title: "Return in Replace",
                  question: "The caret is in the Replace field and you press Return. What happens?",
                  choices: [
                      .init(id: "replaceNext", name: "RK0 · Replace this match and go to the next"),
                      .init(id: "findNext", name: "RK1 · Go to the next match; ⌥Return replaces"),
                  ],
                  recommended: "replaceNext",
                  why: "Stepping through with Return, checking each change in the preview, is the safe way to replace in a script; VS Code and Xcode do it. In the Find field Return still finds the next match."),
            .init(id: "afterAll", title: "After Replace All",
                  question: "You press Replace All. How does Echo say what it did?",
                  choices: [
                      .init(id: "count", name: "RA0 · The count says “Replaced 12” until you type again"),
                      .init(id: "toast", name: "RA1 · A notification"),
                      .init(id: "nothing", name: "RA2 · Nothing; the matches are gone"),
                  ],
                  recommended: "count",
                  why: "The answer belongs where you are looking, in the bar; a notification for something you just did is noise."),
            .init(id: "undo", title: "Undo",
                  question: "You press ⌘Z after Replace All. What comes back?",
                  choices: [
                      .init(id: "all", name: "UN0 · Every replacement, in one step"),
                      .init(id: "each", name: "UN1 · One replacement per ⌘Z"),
                  ],
                  recommended: "all",
                  why: "Replace All is one action, so it should undo as one; twelve ⌘Z presses for one click is how scripts get half-reverted."),
            .init(id: "findAgain", title: "⌘F with Replace open",
                  question: "Replace is open and you press ⌘F. What happens?",
                  choices: [
                      .init(id: "keep", name: "FO0 · Replace stays open; the caret goes to Find"),
                      .init(id: "close", name: "FO1 · Replace closes; Find only"),
                  ],
                  recommended: "keep",
                  why: "⌘F means “take me to the search”, not “undo my Replace”; closing it loses the replacement you typed."),
        ],
        exhibitTopic: ("Search and replace", "Replace in the Proposal with each choice. Is it better than Echo today?", "proposal",
                       "FB5's glass grows to show Replace, every change reads as a diff before you press anything, and the keys are the Mac's."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Inline diff, the capsule grows, ⌘F and ⌥⌘F.",
                  values: ["replacePreview": LabQEReplacePreview.inlineDiff.rawValue, "replaceOpening": LabQEReplaceOpening.grow.rawValue,
                           "findShortcuts": LabQEFindShortcuts.macOS.rawValue],
                  isRecommended: true),
            .init(id: "calm", name: "Calm", summary: "Only the current match previews; the glass row melts out.",
                  values: ["replacePreview": LabQEReplacePreview.currentOnly.rawValue, "replaceOpening": LabQEReplaceOpening.morph.rawValue,
                           "findShortcuts": LabQEFindShortcuts.macOS.rawValue]),
        ]
    )
}

/// Every preview side by side, text only.
struct LabQEPreviewGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: SpacingTokens.md), GridItem(.flexible(), spacing: SpacingTokens.md)],
                  alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(LabQEReplacePreview.allCases, id: \.self) { preview in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(preview.rawValue).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                    LabQESearchReplacePlayground(preview: preview, opening: .instant, shortcuts: .macOS, compact: true)
                        .frame(height: 180)
                }
            }
        }
        .padding(SpacingTokens.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Edit › Find, drawn like the menu, with the chosen shortcuts.
struct LabQEFindMenu: View {
    let shortcuts: LabQEFindShortcuts

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            item("Find…", "⌘F")
            item("Find and Replace…", shortcuts.replaceKeys)
            Divider().padding(.vertical, SpacingTokens.xxs)
            item("Find Next", "⌘G")
            item("Find Previous", "⇧⌘G")
            item("Use Selection for Find", "⌘E")
            item("Jump to Selection", "⌘J")
        }
        .font(TypographyTokens.standard)
        .padding(SpacingTokens.xs)
        .frame(width: 280)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func item(_ title: String, _ keys: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys).foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
    }
}
