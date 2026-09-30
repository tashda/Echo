import SwiftUI

/// Everything one Run button is drawn with. Round 20's two pages each set half of it; a proposal
/// reads both pages' controls, so each page shows the whole button you are building.
struct LabRBLook: Equatable {
    var form: LabRBForm = .plainGlyph
    var icon: LabRBIcon = .playFill
    var colour: LabRBColour = .primary
    var selection: LabRBSelection = .accentGlyph
    var hover: LabRBHover = .none
    var unavailable: LabRBUnavailable = .dimmed
    var menu: LabRBMenu = .rightClick
    var memory: LabRBMemory = .alwaysRun
    var running: LabRBRunning = .redProminent
    var stopIcon: LabRBStopIcon = .stopFill
    var runningMotion: LabRBRunningMotion = .still
    var change: LabRBChange = .replace
    var result: LabRBResult = .glyph
    var hold: LabRBHold = .today
    var delay: LabRBDelay = .atOnce
    var timerFormat: LabRBTimerFormat = .clock

    /// Run as Echo draws it today (QueryRunToolbarControl).
    static let today = LabRBLook()

    /// The proposal: page 1's controls for the look at rest, page 2's for running.
    @MainActor static func proposal() -> LabRBLook {
        let rest = LabRBPages.lookValues
        let run = LabRBPages.runningValues
        var look = LabRBLook()
        look.form = LabRBForm(rawValue: rest["form"]) ?? look.form
        look.icon = LabRBIcon(rawValue: rest["icon"]) ?? look.icon
        look.colour = LabRBColour(rawValue: rest["colour"]) ?? look.colour
        look.selection = LabRBSelection(rawValue: rest["selection"]) ?? look.selection
        look.hover = LabRBHover(rawValue: rest["hover"]) ?? look.hover
        look.unavailable = LabRBUnavailable(rawValue: rest["unavailable"]) ?? look.unavailable
        look.menu = LabRBMenu(rawValue: rest["menu"]) ?? look.menu
        look.memory = LabRBMemory(rawValue: rest["memory"]) ?? look.memory
        look.running = LabRBRunning(rawValue: run["running"]) ?? look.running
        look.stopIcon = LabRBStopIcon(rawValue: run["stopIcon"]) ?? look.stopIcon
        look.runningMotion = LabRBRunningMotion(rawValue: run["motion"]) ?? look.runningMotion
        look.change = LabRBChange(rawValue: run["change"]) ?? look.change
        look.result = LabRBResult(rawValue: run["result"]) ?? look.result
        look.hold = LabRBHold(rawValue: run["hold"]) ?? look.hold
        look.delay = LabRBDelay(rawValue: run["delay"]) ?? look.delay
        look.timerFormat = LabRBTimerFormat(rawValue: run["timer"]) ?? look.timerFormat
        return look
    }

    func with<Value>(_ path: WritableKeyPath<LabRBLook, Value>, _ value: Value) -> LabRBLook {
        var copy = self
        copy[keyPath: path] = value
        return copy
    }
}

/// The two pages' saved control values, read by either page.
@MainActor
enum LabRBPages {
    static let lookID = "ongoing.run-button-look-r20"
    static let runningID = "ongoing.run-button-running-r20"

    static var lookValues: RoundValues { RoundValues.shared(pageID: lookID, controls: RunButtonLookRound.spec.controls) }
    static var runningValues: RoundValues { RoundValues.shared(pageID: runningID, controls: RunButtonRunningRound.spec.controls) }

    /// The playground knobs, which live on page 1 (editor state) and page 2 (outcome, length) but
    /// apply to both, plus the speed of the page being shown.
    static func editorState() -> LabRBEditorState {
        LabRBEditorState(rawValue: lookValues["editor"]) ?? .ready
    }

    static func motion(_ values: RoundValues, reduceMotion: Bool) -> EchoMotion {
        (LabSpeed(rawValue: values["speed"]) ?? .standard).motion(reduceMotion: reduceMotion)
    }
}
