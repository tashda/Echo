import Foundation

enum SQLCompletionAggressiveness: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case focused
    case balanced
    case eager

    var displayName: String {
        switch self {
        case .focused: return "Focused"
        case .balanced: return "Balanced"
        case .eager: return "Eager"
        }
    }
}

struct SQLEditorDisplayOptions: Codable, Equatable {
    var showLineNumbers: Bool
    var highlightSelectedSymbol: Bool
    var highlightDelay: Double
    var wrapLines: Bool
    var indentWrappedLines: Int
    var autoCompletionEnabled: Bool
    var suggestTableAliasesInCompletion: Bool
    var qualifyTableCompletions: Bool
    var suggestKeywordsInCompletion: Bool
    var inlineKeywordSuggestionsEnabled: Bool
    var suggestFunctionsInCompletion: Bool
    var suggestSnippetsInCompletion: Bool
    var suggestHistoryInCompletion: Bool
    var suggestJoinsInCompletion: Bool
    var completionAggressiveness: SQLCompletionAggressiveness
    var allowCommandPeriodTrigger: Bool
    var allowControlSpaceTrigger: Bool
    var showSystemSchemasInCompletion: Bool

    init(
        showLineNumbers: Bool = true,
        highlightSelectedSymbol: Bool = true,
        highlightDelay: Double = 0.25,
        wrapLines: Bool = true,
        indentWrappedLines: Int = 4,
        autoCompletionEnabled: Bool = true,
        suggestTableAliasesInCompletion: Bool = false,
        qualifyTableCompletions: Bool = false,
        suggestKeywordsInCompletion: Bool = true,
        inlineKeywordSuggestionsEnabled: Bool = true,
        suggestFunctionsInCompletion: Bool = true,
        suggestSnippetsInCompletion: Bool = true,
        suggestHistoryInCompletion: Bool = true,
        suggestJoinsInCompletion: Bool = true,
        completionAggressiveness: SQLCompletionAggressiveness = .balanced,
        allowCommandPeriodTrigger: Bool = true,
        allowControlSpaceTrigger: Bool = true,
        showSystemSchemasInCompletion: Bool = false
    ) {
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedSymbol = highlightSelectedSymbol
        self.highlightDelay = highlightDelay
        self.wrapLines = wrapLines
        self.indentWrappedLines = indentWrappedLines
        self.autoCompletionEnabled = autoCompletionEnabled
        self.suggestTableAliasesInCompletion = suggestTableAliasesInCompletion
        self.qualifyTableCompletions = qualifyTableCompletions
        self.suggestKeywordsInCompletion = suggestKeywordsInCompletion
        self.inlineKeywordSuggestionsEnabled = inlineKeywordSuggestionsEnabled
        self.suggestFunctionsInCompletion = suggestFunctionsInCompletion
        self.suggestSnippetsInCompletion = suggestSnippetsInCompletion
        self.suggestHistoryInCompletion = suggestHistoryInCompletion
        self.suggestJoinsInCompletion = suggestJoinsInCompletion
        self.completionAggressiveness = completionAggressiveness
        self.allowCommandPeriodTrigger = allowCommandPeriodTrigger
        self.allowControlSpaceTrigger = allowControlSpaceTrigger
        self.showSystemSchemasInCompletion = showSystemSchemasInCompletion
    }

    private enum CodingKeys: String, CodingKey {
        case showLineNumbers
        case highlightSelectedSymbol
        case highlightDelay
        case wrapLines
        case indentWrappedLines
        case autoCompletionEnabled
        case suggestTableAliasesInCompletion
        case qualifyTableCompletions
        case suggestKeywordsInCompletion
        case inlineKeywordSuggestionsEnabled
        case suggestFunctionsInCompletion
        case suggestSnippetsInCompletion
        case suggestHistoryInCompletion
        case suggestJoinsInCompletion
        case completionAggressiveness
        case allowCommandPeriodTrigger
        case allowControlSpaceTrigger
        case showSystemSchemasInCompletion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        highlightSelectedSymbol = try container.decode(Bool.self, forKey: .highlightSelectedSymbol)
        highlightDelay = try container.decode(Double.self, forKey: .highlightDelay)
        wrapLines = try container.decode(Bool.self, forKey: .wrapLines)
        indentWrappedLines = try container.decode(Int.self, forKey: .indentWrappedLines)
        autoCompletionEnabled = try container.decode(Bool.self, forKey: .autoCompletionEnabled)
        suggestTableAliasesInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestTableAliasesInCompletion) ?? false
        qualifyTableCompletions = try container.decodeIfPresent(Bool.self, forKey: .qualifyTableCompletions) ?? false
        suggestKeywordsInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestKeywordsInCompletion) ?? true
        inlineKeywordSuggestionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .inlineKeywordSuggestionsEnabled) ?? true
        suggestFunctionsInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestFunctionsInCompletion) ?? true
        suggestSnippetsInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestSnippetsInCompletion) ?? true
        suggestHistoryInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestHistoryInCompletion) ?? true
        suggestJoinsInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestJoinsInCompletion) ?? true
        completionAggressiveness = try container.decodeIfPresent(SQLCompletionAggressiveness.self, forKey: .completionAggressiveness) ?? .balanced
        allowCommandPeriodTrigger = try container.decodeIfPresent(Bool.self, forKey: .allowCommandPeriodTrigger) ?? true
        allowControlSpaceTrigger = try container.decodeIfPresent(Bool.self, forKey: .allowControlSpaceTrigger) ?? true
        showSystemSchemasInCompletion = try container.decodeIfPresent(Bool.self, forKey: .showSystemSchemasInCompletion) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(highlightSelectedSymbol, forKey: .highlightSelectedSymbol)
        try container.encode(highlightDelay, forKey: .highlightDelay)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(indentWrappedLines, forKey: .indentWrappedLines)
        try container.encode(autoCompletionEnabled, forKey: .autoCompletionEnabled)
        try container.encode(suggestTableAliasesInCompletion, forKey: .suggestTableAliasesInCompletion)
        try container.encode(qualifyTableCompletions, forKey: .qualifyTableCompletions)
        try container.encode(suggestKeywordsInCompletion, forKey: .suggestKeywordsInCompletion)
        try container.encode(inlineKeywordSuggestionsEnabled, forKey: .inlineKeywordSuggestionsEnabled)
        try container.encode(suggestFunctionsInCompletion, forKey: .suggestFunctionsInCompletion)
        try container.encode(suggestSnippetsInCompletion, forKey: .suggestSnippetsInCompletion)
        try container.encode(suggestHistoryInCompletion, forKey: .suggestHistoryInCompletion)
        try container.encode(suggestJoinsInCompletion, forKey: .suggestJoinsInCompletion)
        try container.encode(completionAggressiveness, forKey: .completionAggressiveness)
        try container.encode(allowCommandPeriodTrigger, forKey: .allowCommandPeriodTrigger)
        try container.encode(allowControlSpaceTrigger, forKey: .allowControlSpaceTrigger)
        try container.encode(showSystemSchemasInCompletion, forKey: .showSystemSchemasInCompletion)
    }
}
