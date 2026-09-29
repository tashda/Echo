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
    /// Subtle (numbers only) or tinted (a faint column with an edge).
    var gutterStyle: EditorGutterStyle
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
        gutterStyle: EditorGutterStyle = .subtle,
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
        self.gutterStyle = gutterStyle
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
        case gutterStyle
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
        gutterStyle = (try? container.decodeIfPresent(EditorGutterStyle.self, forKey: .gutterStyle)) ?? .subtle
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
        try container.encode(gutterStyle, forKey: .gutterStyle)
        try container.encode(cardCornerRadius, forKey: .cardCornerRadius)
    }
}
