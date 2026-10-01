import SwiftUI

/// Round 28.1 · Editor: text and line height. The font, size, ligatures, line height and margins.
/// Echo today: JetBrains Mono 13pt in lines 31pt high, because `SQLLayoutManager` multiplies the
/// font's line height by the Line Spacing setting (1.55) and then adds `SQLEditorTheme.lineSpacing`
/// (13 × 0.2 × 1.55) on top. Changes EDT-1.2.
@MainActor
enum EditorTextRound {
    static let spec = RoundSpec(
        controls: [
            .of("lineHeight", "Line height", LabQELineHeight.self, default: .comfortable,
                question: "Compare the line heights side by side, then read the Proposal for a while. How tall should a line of 13pt code be?",
                recommend: .comfortable,
                why: "You decided “13pt with 1.55 line spacing”; read as designers mean it, that is a 20pt line, and the 31pt today is a bug (the setting counted twice). 20pt keeps the airy feel you asked for and shows 50% more code than today. 17pt is Xcode-dense and makes the statement band and squiggles crowd the letters; 23pt is for presenting.",
                summary: \.summary),
            .of("font", "Default font", LabQEFont.self, default: .sfMono,
                question: "Look at the Fonts exhibit, then the Proposal in each. Which font should a new Echo install use?",
                recommend: .sfMono,
                why: "A close call with JetBrains Mono. SF Mono is what Xcode and Terminal use, matches the gutter's SF digits and the rest of the window, and stays crisp at 12 and 13pt; JetBrains Mono's taller lower case reads a little bigger, but looks like an editor from elsewhere. Every bundled font stays in Settings.",
                summary: \.summary),
            .of("size", "Default size", LabQEFontSize.self, default: .s13,
                question: "Should the default stay 13pt?",
                recommend: .s13,
                why: "You decided 13pt on the design board; it matches macOS's body text, so code and the rest of the window feel the same size. Zoom (page 28.8) covers the moments you want it bigger."),
            .of("ligatures", "Ligatures", LabQELigatures.self, default: .off,
                question: "Look at line 6 (>=) and line 7 (<>) with ligatures on and off. Should ligatures be on by default?",
                recommend: .off,
                why: "In SQL, <> and != mean the same but you should see which one you typed, and ≥ hides that it is two characters when you edit it. Fonts that have them can still turn them on in Settings.",
                summary: \.summary),
            .of("codeGap", "Numbers to code", LabQECodeGap.self, default: .g16,
                question: "Look at the space between the line numbers and the code. How wide should it be?",
                recommend: .g16,
                why: "Today's 21pt (12pt after the numbers plus the text view's 9pt inset) makes the numbers read as a separate column; 16pt keeps them clearly apart and joined to their line. 12pt is tight once a dot or arrow is near."),
            .of("topMargin", "Above the first line", LabQETopMargin.self, default: .m8,
                question: "Look at the first line's distance from the card's top edge. How much room should it have?",
                recommend: .m8,
                why: "With 31pt lines today's 4pt is hidden inside the line's own air; with 20pt lines the first line would touch the card's edge. 8pt is the card's own padding (SpacingTokens.xs)."),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("JetBrains Mono 13pt in 31pt lines, ligatures on, code 21pt after the numbers, 4pt from the top.", scene: .typing),
            LabQERound.proposal("Built from the controls; the rest of the editor as you choose under Rest of the editor.", scene: .typing),
            LabQERound.gallery("Line heights", "Every line height on the proposal.", LabQELineHeight.self, \.lineHeight, scene: .typing),
            .init(id: "fonts", title: "Fonts", summary: "Every bundled font and SF Mono at the proposal's size, with and without ligatures.",
                  designWidth: LabQEFontSampler.width, designHeight: LabQEFontSampler.height) { values in
                LabQEFontSampler(size: (LabQEFontSize(rawValue: values["size"]) ?? .s13).points)
            },
        ],
        questions: [
            .init(id: "spacingSetting", title: "The Line Spacing setting",
                  question: "Settings › Editor Font › Line Spacing offers 1.0 to 2.0 today, and every value is counted twice. What should it offer?",
                  choices: [
                      .init(id: "numbers", name: "LS0 · Numbers, × the font size", summary: "1.3, 1.55, 1.75 …: what the number says is what you get."),
                      .init(id: "names", name: "LS1 · Compact, Comfortable, Relaxed", summary: "17, 20 and 23pt at 13pt; scales with the size."),
                      .init(id: "noSetting", name: "LS2 · No setting", summary: "Comfortable for everyone."),
                  ],
                  recommended: "names",
                  why: "Three names say what you get without arithmetic, and nobody needs 1.35 against 1.55. Anyone on today's 1.55 lands on Comfortable."),
        ],
        exhibitTopic: ("Which text?", "Read the script in both. Is the proposal better than Echo today?", "proposal",
                       "A 20pt line shows half as much again of a script, without crowding, and the code starts where the eye expects it."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "SF Mono 13pt, 20pt lines, no ligatures, 16pt gap, 8pt top.",
                  values: ["lineHeight": LabQELineHeight.comfortable.rawValue, "font": LabQEFont.sfMono.rawValue, "size": LabQEFontSize.s13.rawValue,
                           "ligatures": LabQELigatures.off.rawValue, "codeGap": LabQECodeGap.g16.rawValue, "topMargin": LabQETopMargin.m8.rawValue],
                  isRecommended: true),
            .init(id: "fixOnly", name: "Only the line-height fix", summary: "Echo today, with the setting counted once.",
                  values: ["lineHeight": LabQELineHeight.comfortable.rawValue, "font": LabQEFont.jetBrains.rawValue, "size": LabQEFontSize.s13.rawValue,
                           "ligatures": LabQELigatures.on.rawValue, "codeGap": LabQECodeGap.today.rawValue, "topMargin": LabQETopMargin.today.rawValue]),
            .init(id: "xcode", name: "Like Xcode", summary: "SF Mono, the font's own line height.",
                  values: ["lineHeight": LabQELineHeight.natural.rawValue, "font": LabQEFont.sfMono.rawValue, "size": LabQEFontSize.s12.rawValue,
                           "ligatures": LabQELigatures.off.rawValue, "codeGap": LabQECodeGap.g12.rawValue, "topMargin": LabQETopMargin.today.rawValue]),
        ]
    )
}

/// One line of the sample in every font.
struct LabQEFontSampler: View {
    static let width: CGFloat = 640
    static let height: CGFloat = 460

    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(LabQEFont.allCases, id: \.self) { font in
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
                    Text(font.rawValue).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 180, alignment: .leading)
                    Text(verbatim: "AND o.total >= 100 -- 0O 1lI")
                        .font(Font(LabQEFonts.nsFont(font, size: size, ligatures: false)))
                    Text(verbatim: ">= <> !=")
                        .font(Font(LabQEFonts.nsFont(font, size: size, ligatures: true)))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .lineLimit(1)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}
