import SwiftUI

/// Round 28: everything about how the editor draws, in one value. `today` is Echo as built
/// (read from SQLTextView, LineNumberRulerView, SQLLayoutManager and the Aurora/Midnight
/// palettes); `recommended` is every page's recommendation together. A page's controls override
/// the parts they name (`applying(_:)`), on top of whichever base the owner picks.
struct LabQEStyle {
    var font = LabQEFont.jetBrains
    var size = LabQEFontSize.s13
    var ligatures = LabQELigatures.on
    var lineHeight = LabQELineHeight.today
    var codeGap = LabQECodeGap.today
    var topMargin = LabQETopMargin.today
    var gutter = LabQEGutterSurface.subtle
    var numberFont = LabQENumberFont.today
    var numberColour = LabQENumberColour.palette
    var currentNumber = LabQECurrentNumber.today
    var markers = LabQEMarkerPlace.left
    var currentLine = LabQECurrentLine.band
    var selectionColour = LabQESelectionColour.palette
    var selectionShape = LabQESelectionShape.square
    var caret = LabQECaretColour.operatorColour
    var statement = LabQEStatementLook.band
    var runArrow = LabQERunArrow.triangle
    var wordHighlight = LabQEWordHighlight.today
    var markCorner = LabQEMarkCorner.c0
    var markHeight = LabQEMarkHeight.line
    var errorWord = LabQEErrorWord.glow
    var errorMessage = LabQEErrorMessage.pill
    var errorDot = LabQEErrorDot.dot
    var runNoteLook = LabQERunNoteLook.today
    var runNotePlace = LabQERunNotePlace.lineEnd
    var ranHighlight = LabQERanHighlight.nothing
    var zoom = LabQEZoomLevel.z100
    /// Nil: no zoom control (Echo today).
    var zoomPlace: LabQEZoomPlace?
    var zoomLook = LabQEZoomLook.menu
    var zoomShows = LabQEZoomShows.always

    static let today = LabQEStyle()

    static let recommended = LabQEStyle(
        font: .sfMono, size: .s13, ligatures: .off, lineHeight: .comfortable, codeGap: .g16, topMargin: .m8,
        gutter: .subtle, numberFont: .smaller, numberColour: .tertiary, currentNumber: .primary, markers: .left,
        currentLine: .noBand, selectionColour: .system, selectionShape: .square, caret: .accent,
        statement: .bracket, runArrow: .symbol, wordHighlight: .soft, markCorner: .c3, markHeight: .letters,
        errorWord: .squiggle, errorMessage: .hover, errorDot: .dot,
        runNoteLook: .quiet, runNotePlace: .lineEnd, ranHighlight: .flash,
        zoom: .z100, zoomPlace: .bottomLeft, zoomLook: .menu, zoomShows: .always)

    /// The base with every control in `values` that names a part of the style.
    @MainActor func applying(_ values: RoundValues) -> LabQEStyle {
        var style = self
        func set<E: RawRepresentable>(_ key: String, _ path: WritableKeyPath<LabQEStyle, E>) where E.RawValue == String {
            if let value = E(rawValue: values[key]) { style[keyPath: path] = value }
        }
        set("font", \.font); set("size", \.size); set("ligatures", \.ligatures); set("lineHeight", \.lineHeight)
        set("codeGap", \.codeGap); set("topMargin", \.topMargin); set("gutter", \.gutter); set("numberFont", \.numberFont)
        set("numberColour", \.numberColour); set("currentNumber", \.currentNumber); set("markers", \.markers)
        set("currentLine", \.currentLine); set("selectionColour", \.selectionColour); set("selectionShape", \.selectionShape)
        set("caret", \.caret); set("statement", \.statement); set("runArrow", \.runArrow); set("wordHighlight", \.wordHighlight)
        set("markCorner", \.markCorner); set("markHeight", \.markHeight); set("errorWord", \.errorWord)
        set("errorMessage", \.errorMessage); set("errorDot", \.errorDot); set("runNoteLook", \.runNoteLook)
        set("runNotePlace", \.runNotePlace); set("ranHighlight", \.ranHighlight); set("zoom", \.zoom)
        set("zoomLook", \.zoomLook); set("zoomShows", \.zoomShows)
        if let place = LabQEZoomPlace(rawValue: values["zoomPlace"]) { style.zoomPlace = place }
        return style
    }
}

/// What the rest of the editor looks like around the part a page is about.
enum LabQEBase: String, CaseIterable {
    case recommended = "Everything else as I recommend"
    case today = "Everything else as Echo today"

    var style: LabQEStyle { self == .today ? .today : .recommended }

    /// The proposal on a page: this base with the page's controls.
    @MainActor static func proposal(_ values: RoundValues) -> LabQEStyle {
        (LabQEBase(rawValue: values["base"]) ?? .recommended).style.applying(values)
    }
}

/// What is happening in the editor: where the caret is, what is selected, what went wrong.
struct LabQEScene {
    var misspelled = false
    var hasCaret = true
    var selection = false
    var wordHighlight = true
    var find = false
    var liveError = false
    var serverError = false
    var runNote: LabQERunResult?
    /// The caret on the error's line (shows the bubble for M3).
    var caretOnError = false
    var empty = false
    var isWindowActive = true
}

enum LabQERunResult: Equatable {
    case rows(Int, seconds: Double)
    case error
}

/// The scenes the pages offer as a playground control.
enum LabQESceneChoice: String, CaseIterable {
    case typing = "Typing"
    case selection = "Text selected"
    case find = "Finding “orders”"
    case liveError = "A mistake while typing"
    case afterRun = "After a run"
    case afterError = "After a failed run"
    case inactive = "Window in the background"

    var scene: LabQEScene {
        switch self {
        case .typing: LabQEScene()
        case .selection: LabQEScene(selection: true)
        case .find: LabQEScene(wordHighlight: false, find: true)
        case .liveError: LabQEScene(misspelled: true, liveError: true)
        case .afterRun: LabQEScene(runNote: .rows(14_870, seconds: 10.1))
        case .afterError: LabQEScene(misspelled: true, serverError: true, runNote: .error)
        case .inactive: LabQEScene(selection: true, isWindowActive: false)
        }
    }
}
