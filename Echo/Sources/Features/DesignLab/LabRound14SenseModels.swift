#if DEBUG
import AppKit
import SwiftUI

/// Round 14 · ESR4: how the selected suggestion looks while typing and while choosing.
enum LabSenseSelection: String, CaseIterable, Identifiable {
    case tintThenSolid = "ESR4 · Tint, then solid"
    case alwaysSolid = "Today · Always solid"
    case alwaysTint = "Always tint"
    var id: String { rawValue }

    func isSolid(navigating: Bool) -> Bool {
        switch self {
        case .tintThenSolid: navigating
        case .alwaysSolid: true
        case .alwaysTint: false
        }
    }
}

/// ESR5: the popup's corner follows Settings › Appearance › Card Corners, capped so the rows
/// inside stay concentric; or a fixed corner for comparison.
enum LabSenseCorners: String, CaseIterable, Identifiable {
    case followCards = "Follow card corners"
    case fixed = "Fixed 10pt"
    var id: String { rawValue }

    func popupRadius(cardRadius: CGFloat) -> CGFloat {
        switch self {
        case .followCards: min(cardRadius, LayoutTokens.DesignLabRound14.sensePopupMaxCorner)
        case .fixed: SpacingTokens.xs2
        }
    }
}

enum LabCardCornerSetting: String, CaseIterable, Identifiable {
    case ten = "10", twelve = "12", sixteen = "16", twenty = "20", twentySix = "26"
    var id: String { rawValue }
    var radius: CGFloat { CGFloat(Double(rawValue) ?? 16) }
}

struct LabSuggestion: Identifiable, Equatable {
    enum Kind: String { case column = "C", table = "T", function = "ƒ", keyword = "K" }

    let id: String
    let kind: Kind
    let name: String
    var alias: String? = nil
    var source: String? = nil
    let type: String
    let detail: String

    var badgeColor: Color {
        switch kind {
        case .column: ColorTokens.Explorer.views
        case .table: ColorTokens.Explorer.tables
        case .function: ColorTokens.Explorer.functions
        case .keyword: ColorTokens.Text.secondary
        }
    }

    var kindTitle: String {
        switch kind {
        case .column: "Column"
        case .table: "Table"
        case .function: "Function"
        case .keyword: "Keyword"
        }
    }

    /// What gets inserted: same-named columns keep their alias (ESR3).
    var insertion: String { alias.map { "\($0).\(name)" } ?? name }

    static let all: [LabSuggestion] = [
        LabSuggestion(id: "soh.CustomerID", kind: .column, name: "CustomerID", alias: "soh", source: "Sales.SalesOrderHeader", type: "int", detail: "not null · foreign key to Sales.Customer"),
        LabSuggestion(id: "c.CustomerID", kind: .column, name: "CustomerID", alias: "c", source: "Sales.Customer", type: "int", detail: "not null · primary key"),
        LabSuggestion(id: "soh.CurrencyRateID", kind: .column, name: "CurrencyRateID", alias: "soh", source: "Sales.SalesOrderHeader", type: "int", detail: "null · foreign key to Sales.CurrencyRate"),
        LabSuggestion(id: "soh.CreditCardID", kind: .column, name: "CreditCardID", alias: "soh", source: "Sales.SalesOrderHeader", type: "int", detail: "null · foreign key to Sales.CreditCard"),
        LabSuggestion(id: "soh.Comment", kind: .column, name: "Comment", alias: "soh", source: "Sales.SalesOrderHeader", type: "nvarchar(128)", detail: "null"),
        LabSuggestion(id: "soh.TotalDue", kind: .column, name: "TotalDue", alias: "soh", source: "Sales.SalesOrderHeader", type: "money", detail: "not null · computed"),
        LabSuggestion(id: "soh.TaxAmt", kind: .column, name: "TaxAmt", alias: "soh", source: "Sales.SalesOrderHeader", type: "money", detail: "not null"),
        LabSuggestion(id: "t.Customer", kind: .table, name: "Customer", source: "Sales", type: "table", detail: "19 820 rows"),
        LabSuggestion(id: "t.CreditCard", kind: .table, name: "CreditCard", source: "Sales", type: "table", detail: "19 118 rows"),
        LabSuggestion(id: "f.CURRENT_TIMESTAMP", kind: .function, name: "CURRENT_TIMESTAMP", type: "datetime", detail: "The current date and time"),
        LabSuggestion(id: "f.COUNT", kind: .function, name: "COUNT", type: "int", detail: "COUNT ( { [ ALL | DISTINCT ] expression } | * )"),
        LabSuggestion(id: "k.CUBE", kind: .keyword, name: "CUBE", type: "keyword", detail: "GROUP BY CUBE ( … )"),
        LabSuggestion(id: "k.CASE", kind: .keyword, name: "CASE", type: "keyword", detail: "CASE WHEN … THEN … END"),
    ]

    /// Prefix matches first, then anywhere in the name.
    static func matches(for word: String) -> [LabSuggestion] {
        guard !word.isEmpty else { return [] }
        let lower = word.lowercased()
        let prefix = all.filter { $0.name.lowercased().hasPrefix(lower) }
        let inside = all.filter { !$0.name.lowercased().hasPrefix(lower) && $0.name.lowercased().contains(lower) }
        return Array((prefix + inside).prefix(8))
    }
}

extension TypographyTokens {
    /// The editor font for the round 14 EchoSense page (today's bundled default).
    enum DesignLabRound14 {
        static let editorSize: CGFloat = 13
        static let editorName = "JetBrainsMono-Regular"
        static let editor = Font.custom(editorName, size: editorSize)
        static let editorBold = Font.custom(editorName, size: editorSize).weight(.bold)
        static var editorNSFont: NSFont {
            NSFont(name: editorName, size: editorSize) ?? .monospacedSystemFont(ofSize: editorSize, weight: .regular)
        }
    }
}
#endif
