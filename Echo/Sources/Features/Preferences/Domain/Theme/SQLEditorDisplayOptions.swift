import Foundation

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

    init(
        showLineNumbers: Bool = true,
        highlightSelectedSymbol: Bool = true,
        highlightDelay: Double = 0.25,
        wrapLines: Bool = true,
        indentWrappedLines: Int = 4,
        autoCompletionEnabled: Bool = true,
        qualifyTableCompletions: Bool = false,
        showSystemSchemasInCompletion: Bool = false,
        liveValidationEnabled: Bool = true
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
    }
}
