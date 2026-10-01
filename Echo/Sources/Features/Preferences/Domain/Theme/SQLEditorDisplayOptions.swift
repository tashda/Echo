import Foundation
import CoreGraphics

struct SQLEditorDisplayOptions: Codable, Equatable {
    var showLineNumbers: Bool
    var highlightSelectedSymbol: Bool
    var highlightDelay: Double
    var wrapLines: Bool
    var indentWrappedLines: Int
    var autoCompletionEnabled: Bool
    var qualifyTableCompletions: Bool
    var showSystemSchemasInCompletion: Bool
    var liveValidationEnabled: Bool
    /// QE1: a faint band on the statement at the caret and a Run arrow in the gutter.
    var statementFocusEnabled: Bool
    /// QE5: the outline strip on the editor's right edge, in place of the scroll bar.
    var outlineEdgeEnabled: Bool
    /// ES3: the top suggestion as grey text after the caret, Tab accepts; the popup on demand.
    var ghostTextEnabled: Bool
    /// Subtle (numbers only) or tinted (a faint column with an edge).
    var gutterStyle: EditorGutterStyle
    /// Round 28.15: the corner of every mark and of the selection, and how strong marks are.
    var markCorners: EditorMarkCorners
    var markStrength: EditorMarkStrength
    /// Settings › Appearance › Card Corners; the EchoSense popup follows it (capped).
    var cardCornerRadius: CGFloat

    init(
        showLineNumbers: Bool = true,
        highlightSelectedSymbol: Bool = true,
        highlightDelay: Double = 0.25,
        wrapLines: Bool = true,
        indentWrappedLines: Int = 4,
        autoCompletionEnabled: Bool = true,
        qualifyTableCompletions: Bool = false,
        showSystemSchemasInCompletion: Bool = false,
        liveValidationEnabled: Bool = true,
        statementFocusEnabled: Bool = true,
        outlineEdgeEnabled: Bool = false,
        ghostTextEnabled: Bool = false,
        gutterStyle: EditorGutterStyle = .subtle,
        markCorners: EditorMarkCorners = .round,
        markStrength: EditorMarkStrength = .standard,
        cardCornerRadius: CGFloat = LayoutTokens.Workspace.cardCornerRadius
    ) {
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedSymbol = highlightSelectedSymbol
        self.highlightDelay = highlightDelay
        self.wrapLines = wrapLines
        self.indentWrappedLines = indentWrappedLines
        self.autoCompletionEnabled = autoCompletionEnabled
        self.qualifyTableCompletions = qualifyTableCompletions
        self.showSystemSchemasInCompletion = showSystemSchemasInCompletion
        self.liveValidationEnabled = liveValidationEnabled
        self.statementFocusEnabled = statementFocusEnabled
        self.outlineEdgeEnabled = outlineEdgeEnabled
        self.ghostTextEnabled = ghostTextEnabled
        self.gutterStyle = gutterStyle
        self.markCorners = markCorners
        self.markStrength = markStrength
        self.cardCornerRadius = cardCornerRadius
    }

    private enum CodingKeys: String, CodingKey {
        case showLineNumbers
        case highlightSelectedSymbol
        case highlightDelay
        case wrapLines
        case indentWrappedLines
        case autoCompletionEnabled
        case qualifyTableCompletions
        case showSystemSchemasInCompletion
        case liveValidationEnabled
        case statementFocusEnabled
        case outlineEdgeEnabled
        case ghostTextEnabled
        case gutterStyle
        case markCorners
        case markStrength
        case cardCornerRadius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        highlightSelectedSymbol = try container.decode(Bool.self, forKey: .highlightSelectedSymbol)
        highlightDelay = try container.decode(Double.self, forKey: .highlightDelay)
        wrapLines = try container.decode(Bool.self, forKey: .wrapLines)
        indentWrappedLines = try container.decode(Int.self, forKey: .indentWrappedLines)
        autoCompletionEnabled = try container.decode(Bool.self, forKey: .autoCompletionEnabled)
        qualifyTableCompletions = try container.decodeIfPresent(Bool.self, forKey: .qualifyTableCompletions) ?? false
        showSystemSchemasInCompletion = try container.decodeIfPresent(Bool.self, forKey: .showSystemSchemasInCompletion) ?? false
        liveValidationEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveValidationEnabled) ?? true
        statementFocusEnabled = try container.decodeIfPresent(Bool.self, forKey: .statementFocusEnabled) ?? true
        outlineEdgeEnabled = try container.decodeIfPresent(Bool.self, forKey: .outlineEdgeEnabled) ?? false
        ghostTextEnabled = try container.decodeIfPresent(Bool.self, forKey: .ghostTextEnabled) ?? false
        gutterStyle = (try? container.decodeIfPresent(EditorGutterStyle.self, forKey: .gutterStyle)) ?? .subtle
        markCorners = (try? container.decodeIfPresent(EditorMarkCorners.self, forKey: .markCorners)) ?? .round
        markStrength = (try? container.decodeIfPresent(EditorMarkStrength.self, forKey: .markStrength)) ?? .standard
        cardCornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cardCornerRadius) ?? LayoutTokens.Workspace.cardCornerRadius
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(highlightSelectedSymbol, forKey: .highlightSelectedSymbol)
        try container.encode(highlightDelay, forKey: .highlightDelay)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(indentWrappedLines, forKey: .indentWrappedLines)
        try container.encode(autoCompletionEnabled, forKey: .autoCompletionEnabled)
        try container.encode(qualifyTableCompletions, forKey: .qualifyTableCompletions)
        try container.encode(showSystemSchemasInCompletion, forKey: .showSystemSchemasInCompletion)
        try container.encode(liveValidationEnabled, forKey: .liveValidationEnabled)
        try container.encode(statementFocusEnabled, forKey: .statementFocusEnabled)
        try container.encode(outlineEdgeEnabled, forKey: .outlineEdgeEnabled)
        try container.encode(ghostTextEnabled, forKey: .ghostTextEnabled)
        try container.encode(gutterStyle, forKey: .gutterStyle)
        try container.encode(markCorners, forKey: .markCorners)
        try container.encode(markStrength, forKey: .markStrength)
        try container.encode(cardCornerRadius, forKey: .cardCornerRadius)
    }
}
