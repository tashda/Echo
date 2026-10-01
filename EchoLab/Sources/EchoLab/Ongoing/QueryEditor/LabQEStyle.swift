import SwiftUI

/// Round 28: everything about how the editor draws, in one value. `before28` is Echo as it was
/// when round 28 began (read from SQLTextView, LineNumberRulerView, SQLLayoutManager and the
/// Aurora/Midnight palettes); `today` is Echo with the accepted pages built in (28.1 to 28.4);
/// `recommended` is every page's recommendation, with the owner's answers where there are some. A page's controls override
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
    var selectionColour = LabQESelectionColour.system
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
    var findLook = LabQEFindLook.native
    var errorGlow = LabQEErrorGlow.today
    var runningMark = LabQERunningMark.nothing
    var errorBubble = LabQEErrorBubbleLook.today
    var findBar = LabQEFindBarPlace.native
    var findOptions = LabQEFindOptions.menu
    var findCount = LabQEFindCount.found
    var replaceStyle = LabQEReplaceStyle.secondRow
    var findScope = LabQEFindScope.editor

    static let before28 = LabQEStyle()

    /// Built into Echo: 28.1 text, 28.2 gutter, 28.3 caret line and selection, 28.4 statement.
    static let today = LabQEStyle(
        font: .sfMono, size: .s13, ligatures: .off, lineHeight: .comfortable, codeGap: .g16, topMargin: .m8,
        gutter: .subtle, numberFont: .smaller, numberColour: .tertiary, currentNumber: .primary, markers: .left,
        currentLine: .noBand, selectionColour: .system, selectionShape: .rounded, caret: .accent,
        statement: .bracket, runArrow: .symbol)

    static let recommended = LabQEStyle(
        font: .sfMono, size: .s13, ligatures: .off, lineHeight: .comfortable, codeGap: .g16, topMargin: .m8,
        gutter: .subtle, numberFont: .smaller, numberColour: .tertiary, currentNumber: .primary, markers: .left,
        currentLine: .noBand, selectionColour: .system, selectionShape: .rounded, caret: .accent,
        statement: .bracket, runArrow: .symbol, wordHighlight: .soft, markCorner: .followSelection, markHeight: .letters,
        errorWord: .glow, errorMessage: .hover, errorDot: .dot,
        runNoteLook: .glassSymbol, runNotePlace: .lineEnd, ranHighlight: .gutterLine,
        zoom: .z100, zoomPlace: .bottomLeft, zoomLook: .menu, zoomShows: .always, errorGlow: .hairlineHalo,
        runningMark: .breathe, errorBubble: .card)
        .with { $0.findBar = .safari; $0.replaceStyle = .preview; $0.findScope = .selectionButton }

    func with(_ change: (inout LabQEStyle) -> Void) -> LabQEStyle {
        var copy = self
        change(&copy)
        return copy
    }

    /// The gallery's handle on the find look, by the preview control's names.
    var findPreview: LabQEFindPreview {
        get { LabQEFindPreview.allCases.first { $0.look == findLook } ?? .native }
        set { findLook = newValue.look }
    }

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
        set("errorGlow", \.errorGlow); set("runningMark", \.runningMark); set("errorBubble", \.errorBubble); set("findBar", \.findBar); set("findOptions", \.findOptions); set("findCount", \.findCount)
        set("replaceStyle", \.replaceStyle); set("findScope", \.findScope)
        if let preview = LabQEFindPreview(rawValue: values["findPreview"]) { style.findLook = preview.look }
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
    /// The find bar with its Replace row open.
    var showsReplace = false
    /// The first statement's query is running (28.7 rev 3).
    var isRunning = false
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
    case replace = "Replacing “orders”"
    case findInSelection = "Finding in a selection"
    case liveError = "A mistake while typing"
    case liveErrorCaret = "A mistake, caret on its line"
    case running = "Running"
    case afterRun = "After a run"
    case afterError = "After a failed run"
    case inactive = "Window in the background"

    var scene: LabQEScene {
        switch self {
        case .typing: LabQEScene()
        case .selection: LabQEScene(selection: true)
        case .find: LabQEScene(wordHighlight: false, find: true)
        case .replace: LabQEScene(wordHighlight: false, find: true, showsReplace: true)
        case .findInSelection: LabQEScene(selection: true, wordHighlight: false, find: true)
        case .liveError: LabQEScene(misspelled: true, liveError: true)
        case .liveErrorCaret: LabQEScene(misspelled: true, liveError: true, caretOnError: true)
        case .running: LabQEScene(isRunning: true)
        case .afterRun: LabQEScene(runNote: .rows(14_870, seconds: 10.1))
        case .afterError: LabQEScene(misspelled: true, serverError: true, runNote: .error)
        case .inactive: LabQEScene(selection: true, isWindowActive: false)
        }
    }
}
