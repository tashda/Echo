import SwiftUI

/// Every delay and duration of the story, in seconds at normal speed. The choreography
/// (LabOCScene) and the timing chart (LabOCTimelineExhibit) both read this table, so the chart is
/// what the stage does.
enum LabOCTimings {
    // The mark (Mark.astro on echodb.dev).
    static let pillDuration = 0.9
    static let pillStagger = 0.12
    static let ghostLag = 0.09
    static let markStart = 0.25
    static let leaveDuration = 0.34
    static let leaveStagger = 0.06
    static var leaveTotal: Double { leaveDuration + leaveStagger * 2 }

    // The rest of the welcome rising in.
    static let restDelay = 0.55
    static let restGap = 0.15
    static let riseDuration = 0.45

    // Connecting.
    static let columnsDuration = 0.45
    static let railDuration = 0.3
    static let treeLag = 0.12
    static let stayFade = 0.25
    static let pageFade = 0.25
    static let pieceGap = 0.06
    static let pieceDuration = 0.35
    static let pieceCount = 4
    static let cascadeStartOffset = 0.15

    // Closing a tab.
    static let revealDuration = 0.28
    static let leaveCardDuration = 0.2
    static let tabFade = 0.45

    /// How long a cascade of pieces takes in all.
    static var cascadeTotal: Double { pieceGap * Double(pieceCount - 1) + pieceDuration }

    /// When the columns start after the connect click.
    static func columnsStart(_ look: LabOCLook) -> Double { look.leave == .pillsOut ? leaveTotal + 0.06 : 0 }
}

/// What a bar in the timing chart stands for.
enum LabOCBarRole {
    case move, fade, build

    var color: Color {
        switch self {
        case .move: ColorTokens.Status.info
        case .fade: ColorTokens.Text.tertiary
        case .build: ColorTokens.Status.success
        }
    }
}

struct LabOCBar: Identifiable {
    let id: String
    let row: String
    let label: String
    let start: Double
    let duration: Double
    let role: LabOCBarRole
}

/// The chart's rows for each moment, from the same table the stage runs on.
enum LabOCBars {
    static func launch(_ look: LabOCLook) -> [LabOCBar] {
        var bars: [LabOCBar] = []
        if look.mark.animates {
            bars.append(LabOCBar(id: "mark", row: "Mark", label: look.mark == .ghosts ? "pills echo in, with ghosts" : "pills echo in",
                                 start: LabOCTimings.markStart, duration: LabOCTimings.pillDuration + LabOCTimings.pillStagger * 2, role: .move))
        }
        if look.rest == .rise {
            let start = LabOCTimings.markStart + LabOCTimings.restDelay
            bars.append(LabOCBar(id: "buttons", row: "Buttons", label: "rise in", start: start, duration: LabOCTimings.riseDuration, role: .fade))
            bars.append(LabOCBar(id: "recents", row: "Recents", label: "rise in", start: start + LabOCTimings.restGap,
                                 duration: LabOCTimings.riseDuration, role: .fade))
        }
        return bars
    }

    static func connect(_ look: LabOCLook) -> [LabOCBar] {
        var bars: [LabOCBar] = []
        let columns = LabOCTimings.columnsStart(look)
        switch look.leave {
        case .pushed:
            bars.append(LabOCBar(id: "welcome", row: "Welcome", label: "pushed right, fading", start: 0, duration: LabOCTimings.columnsDuration, role: .move))
        case .stays:
            bars.append(LabOCBar(id: "welcome", row: "Welcome", label: "fades in place", start: 0, duration: LabOCTimings.stayFade, role: .fade))
        case .pillsOut:
            bars.append(LabOCBar(id: "welcome", row: "Welcome", label: "pills echo out", start: 0, duration: LabOCTimings.leaveTotal, role: .move))
        }
        switch look.columns {
        case .together:
            bars.append(LabOCBar(id: "rail", row: "Rail and tree", label: "slide in together", start: columns, duration: LabOCTimings.columnsDuration, role: .move))
        case .railFirst:
            bars.append(LabOCBar(id: "rail", row: "Rail", label: "server grows in", start: columns, duration: LabOCTimings.railDuration, role: .move))
            bars.append(LabOCBar(id: "tree", row: "Tree", label: "slides out", start: columns + LabOCTimings.treeLag,
                                 duration: LabOCTimings.columnsDuration, role: .move))
        }
        bars.append(pageBar(look, after: columns))
        return bars
    }

    static func close(_ look: LabOCLook) -> [LabOCBar] {
        let destination = look.closeWhere == .serverPage ? "Server page" : "Welcome"
        switch look.closeHow {
        case .crossfade:
            return [LabOCBar(id: "card", row: "Tab card", label: "swaps, scales to 98%", start: 0, duration: LabOCTimings.columnsDuration, role: .move),
                    LabOCBar(id: "page", row: destination, label: "swaps in", start: 0, duration: LabOCTimings.columnsDuration, role: .fade)]
        case .reveal:
            return [LabOCBar(id: "card", row: "Tab card", label: "lifts away", start: 0, duration: LabOCTimings.revealDuration, role: .fade)]
        case .cascade:
            return [LabOCBar(id: "card", row: "Tab card", label: "fades", start: 0, duration: LabOCTimings.leaveCardDuration, role: .fade),
                    LabOCBar(id: "page", row: destination, label: "builds up", start: LabOCTimings.leaveCardDuration - 0.05,
                             duration: LabOCTimings.cascadeTotal, role: .build)]
        }
    }

    private static func pageBar(_ look: LabOCLook, after columns: Double) -> LabOCBar {
        switch look.arrive {
        case .atOnce:
            LabOCBar(id: "page", row: "Server page", label: "there at once", start: columns, duration: LabOCTimings.columnsDuration, role: .fade)
        case .fadeAfter:
            LabOCBar(id: "page", row: "Server page", label: "fades in", start: columns + LabOCTimings.columnsDuration - 0.1,
                     duration: LabOCTimings.pageFade, role: .fade)
        case .cascade:
            LabOCBar(id: "page", row: "Server page", label: "builds up", start: columns + LabOCTimings.cascadeStartOffset,
                     duration: LabOCTimings.cascadeTotal, role: .build)
        }
    }
}
