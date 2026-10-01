import SwiftUI

/// Round 47 · Results: the row-number gutter and the column header. Echo today
/// (ResultTableRowNumberView, ResultTableHeaderView): the gutter is at least six digits wide
/// whatever the row count (about 50pt, most of it empty), the card's own colour with a hairline on
/// its right edge, numbers 12pt tabular right-aligned in the tertiary colour with a "#" over them;
/// selected and hovered rows' numbers turn accent. The column names are left-aligned over data that
/// is right-aligned for numbers, so a number column's name sits far from its figures, and two lines
/// run under the header (the system's, then the gutter's 4pt lower). The owner wants the gutter as
/// good as the editor's and consistent with it, keeping all it does: a click selects the row, a drag
/// extends the selection (and scrolls), a right-click opens the row menu, numbers turn accent for
/// selected and hovered rows, its width is reserved so it doesn't jump while rows stream in, and
/// Settings › Results › Show row numbers. Changes FTR-4.2 and FTR-4.5.
///
/// Accepted 2026-10-01: GS2 (the Hairline, its edge starting below the header), NA0, GW1, HA0, GC2, SR1, RS1
/// and SS0, the results following the editor's gutter style with Hairline the default for both. Built into
/// Echo as FTR-4.5.
@MainActor
enum ResultsGutterRound {
    enum Style: String, CaseIterable {
        case today = "GS0 · The card's colour with an edge line (today)"
        case subtle = "GS1 · Subtle: only the numbers"
        case hairline = "GS2 · Hairline: only the edge"
        case column = "GS3 · Tinted column: full height, hairline edge"
        case lane = "GS4 · Tinted lane: inset, rounded, numbers centred"

        var summary: String {
            switch self {
            case .today: "Echo today: an edge line, nothing else."
            case .subtle: "The editor's default: nothing but the numbers, in the same tertiary grey."
            case .hairline: "A single line beside the numbers: the grid's one vertical rule."
            case .column: "A quiet tint the card's full height, header corner included, with an edge."
            case .lane: "The editor's lane: inset 5pt, corners concentric with the card's, no edge."
            }
        }
    }

    enum Align: String, CaseIterable {
        case right = "NA0 · Right-aligned (today)"
        case centre = "NA1 · Centred"
    }

    enum Width: String, CaseIterable {
        case six = "GW0 · Six digits wide, always (today)"
        case fits = "GW1 · Fits the digits, at least three, and grows"
        case four = "GW2 · Four digits at least, then grows"

        var summary: String {
            switch self {
            case .six: "About 50pt even for 9 rows: most of the gutter is empty."
            case .fits: "The editor's rule: width follows the digit count; it grows once at 1,000 and at 10,000, never while a number is on screen."
            case .four: "Room for a thousand rows before it ever moves."
            }
        }
    }

    enum Headers: String, CaseIterable {
        case left = "HA0 · Left-aligned (today)"
        case data = "HA1 · Aligned with their data: right over numbers, left over text"
        case centre = "HA2 · Centred over every column"
    }

    enum Corner: String, CaseIterable {
        case hash = "GC0 · A grey # (today)"
        case empty = "GC1 · Nothing"
        case selectAll = "GC2 · A # that selects every cell when clicked"
    }

    enum Selected: String, CaseIterable {
        case number = "SR0 · The number turns accent (today)"
        case tint = "SR1 · The number turns accent on the selection's own tint"
        case bar = "SR2 · The number turns accent, with a thin accent bar at the edge"
    }

    enum RowsScene: String, CaseIterable {
        case few = "Rows 1 to 9"
        case thousands = "Rows 1,196 to 1,204"
        case millions = "Rows 1,203,997 to 1,204,005"
    }

    enum SelectionScene: String, CaseIterable {
        case none = "Nothing selected"
        case oneRow = "One row selected"
        case threeRows = "Three rows selected"
    }

    static let spec = RoundSpec(
        controls: [
            .of("style", "Gutter", Style.self, default: .hairline,
                question: "Compare the five in the Every style exhibit, then the Proposal in light and dark at Card Corners 10 and 26. Which gutter should the results have?",
                recommend: Style.hairline,
                why: "The numbers are reference marks, not content, so they should be as quiet as the editor's: GS1 is the editor's default and needs no edge line next to the row selection's own outline. GS3 and GS4 are the editor's options if you want the gutter to read as a column; on a grid with striped rows a tint beside the stripes adds a third shade. GS2 keeps one vertical line, which is what Echo has now.",
                summary: \.summary),
            .of("align", "Numbers", Align.self, default: .right,
                question: "Set Rows to 1,196 to 1,204 and Gutter to the lane. Should the numbers be right-aligned or centred?",
                recommend: .right,
                why: "The gutter's numbers go to six or seven digits; right-aligned they line up by place value, like the figures in the cells beside them. Centring is for the editor's three-digit lane; here a 1,999 → 2,000 step would shift every digit sideways."),
            .of("width", "Width", Width.self, default: .fits,
                question: "Switch Rows between the three scenes. How wide should the gutter be?",
                recommend: .fits,
                why: "The editor's rule, so both gutters follow the digits and nothing is reserved that isn't needed: six digits wide wastes 25pt on a 20-row result. It only changes at a power of ten, and Echo reserves for the row count it knows, so it doesn't jump while rows stream in.",
                summary: \.summary),
            .of("headers", "Column names", Headers.self, default: .left,
                question: "Look at BusinessEntityID, SalesQuota and rowguid against their figures. Where should a column's name sit?",
                recommend: Headers.data,
                why: "Today a number column's name sits at the left of a column whose figures are at its right, so the header and the numbers under it don't line up (the owner's screenshot). Aligning the header with its data is what Numbers, Xcode's tables and Finder do; text columns stay left. Centring everything makes the left edge ragged. The sort arrow moves to the text's other side."),
            .of("corner", "Header corner", Corner.self, default: .selectAll,
                question: "Hover and click the corner in the Proposal. What should the gutter's header hold?",
                recommend: .selectAll,
                why: "The corner above the numbers is where every spreadsheet puts Select All, and it costs nothing: the # stays, and a click does what ⌘A does. Nothing at all would leave an empty square. This is new behaviour, so say so if you don't want it."),
            .of("selected", "Selected rows", Selected.self, default: .tint,
                question: "Set Selection to Three rows selected. How should the gutter show which rows are selected?",
                recommend: .tint,
                why: "The selection is one tinted block with an outline; carrying the tint through the gutter makes the row numbers part of it, and the accent number stays for hover and as the cue. An edge bar (SR2) is the editor's statement bracket, but a row range is a block, not a bracket.",
                summary: nil),
            .of("cross", "Stripes under the numbers", StripeCross.self, default: .stop,
                question: "With Alternate row shading on, should a shaded row run under its number too?",
                recommend: .cross,
                why: "A stripe that stops at the gutter makes every row look cut off from its number; letting it cross ties the number to its row. With a tinted gutter (GS3, GS4) the tint stays on top, so this only matters for the plain styles."),
            .of("rows", "Rows", RowsScene.self, default: .few),
            .of("selection", "Selection", SelectionScene.self, default: .threeRows),
            .of("stripes", "Alternate row shading", LabRGStripes.self, default: .on),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "The gutter and header as they are, with the second line under the header the owner's screenshot shows.",
                  isEchoToday: true, designWidth: LabRGCard.width, designHeight: LabRGCard.height) { values in
                LabRGCard(look: .today(values))
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls; one line under the header, across the gutter too.",
                  designWidth: LabRGCard.width, designHeight: LabRGCard.height) { values in
                LabRGCard(look: .proposal(values))
            },
            .init(id: "styles", title: "Every style", summary: "The five gutters on the same rows, with the other controls applied.",
                  designWidth: LabRGCard.width, designHeight: 3 * LabRGCard.cellHeight + 2 * SpacingTokens.sm + 2 * SpacingTokens.sm) { values in
                LabRGStyles(values: values)
            },
        ],
        questions: [
            .init(id: "setting", title: "One setting or two",
                  question: "The editor's gutter style is a setting (Settings › Editor › Gutter). Should the results' gutter be its own setting?",
                  choices: [.init(id: "follows", name: "SS0 · It follows the editor's gutter style: one setting for both"),
                            .init(id: "own", name: "SS1 · Its own setting under Settings › Results"),
                            .init(id: "fixed", name: "SS2 · No setting: the style chosen here, always")],
                  recommended: "follows",
                  why: "You asked for them to look consistent; one setting guarantees it, and someone who chose the lane in the editor wants it in the results. A second setting lets them drift apart; fixed removes a choice you gave for the editor."),
        ],
        exhibitTopic: ("Which one?", "Compare the Proposal with Echo today in light and dark at Card Corners 10 and 26. Is the proposal better?", "proposal",
                       "A quiet gutter that follows the digits, names aligned with their figures, one line under the header, and nothing lost."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Subtle, right-aligned, fits the digits, names with their data, a Select All corner, tinted selection, stripes across.",
                  values: ["style": Style.subtle.rawValue, "align": Align.right.rawValue, "width": Width.fits.rawValue,
                           "headers": Headers.data.rawValue, "corner": Corner.selectAll.rawValue, "selected": Selected.tint.rawValue,
                           "cross": StripeCross.cross.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["style": Style.today.rawValue, "align": Align.right.rawValue, "width": Width.six.rawValue,
                           "headers": Headers.left.rawValue, "corner": Corner.hash.rawValue, "selected": Selected.number.rawValue,
                           "cross": StripeCross.stop.rawValue]),
            .init(id: "lane", name: "The editor's lane", summary: "The lane as in the editor, numbers centred.",
                  values: ["style": Style.lane.rawValue, "align": Align.centre.rawValue, "width": Width.fits.rawValue,
                           "headers": Headers.data.rawValue, "corner": Corner.hash.rawValue, "selected": Selected.tint.rawValue]),
        ]
    )
}

extension ResultsGutterRound {
    enum StripeCross: String, CaseIterable {
        case cross = "RS0 · Yes: the shaded row crosses the numbers"
        case stop = "RS1 · No: it stops at the gutter (today)"
    }
}

enum LabRGStripes: String, CaseIterable {
    case on = "On"
    case off = "Off"
}
