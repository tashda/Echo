import Foundation

@preconcurrency public let ResultStreamingFetchSizeDefaultsKey = "dk.tippr.echo.streaming.fetchSize"
@preconcurrency public let ResultStreamingFetchRampMultiplierDefaultsKey = "dk.tippr.echo.streaming.fetchRampMultiplier"
@preconcurrency public let ResultStreamingFetchRampMaxDefaultsKey = "dk.tippr.echo.streaming.fetchRampMax"
@preconcurrency public let ResultStreamingUseCursorDefaultsKey = "dk.tippr.echo.streaming.useCursor"
@preconcurrency public let ResultStreamingCursorLimitThresholdDefaultsKey = "dk.tippr.echo.streaming.cursorThreshold"
@preconcurrency public let ResultStreamingModeDefaultsKey = "dk.tippr.echo.streaming.mode"
@preconcurrency public let ResultFormattingEnabledDefaultsKey = "dk.tippr.echo.results.formattingEnabled"
@preconcurrency public let ResultFormattingModeDefaultsKey = "dk.tippr.echo.results.formattingMode"

public enum ResultsFormattingMode: String, Sendable, Codable, CaseIterable, Identifiable {
    case immediate, deferred
    public nonisolated var id: String { rawValue }
    public nonisolated var displayName: String {
        self == .immediate ? "Wait for formatting" : "Show immediately, format later"
    }
}

public enum ResultStreamingExecutionMode: String, Sendable, Codable, CaseIterable, Identifiable {
    case auto, simple, cursor
    public nonisolated var id: String { rawValue }
    public nonisolated var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .simple: return "Simple"
        case .cursor: return "Cursor"
        }
    }
}

public struct FilterCriteria: Sendable {
    public let column: String
    public let `operator`: FilterOperator
    public let value: String
    public init(column: String, `operator`: FilterOperator, value: String) { self.column = column; self.operator = `operator`; self.value = value }
}

public enum FilterOperator: String, CaseIterable, Sendable {
    case equals = "=", notEquals = "!=", contains = "LIKE", startsWith = "STARTS_WITH", endsWith = "ENDS_WITH", greaterThan = ">", lessThan = "<", isNull = "IS NULL", isNotNull = "IS NOT NULL"
}

public struct SortCriteria: Sendable, Equatable {
    public let column: String
    public let ascending: Bool
    public init(column: String, ascending: Bool) { self.column = column; self.ascending = ascending }
}
