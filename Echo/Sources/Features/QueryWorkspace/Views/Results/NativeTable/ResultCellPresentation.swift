#if os(macOS)
import AppKit

/// How a results cell shows its value (Design/05-components.md › Results card): numbers and
/// dates right-aligned with tabular digits, booleans as ✓ and ✗, NULL as today's italic text.
/// Only the display changes; copying and exporting still use the raw values.
nonisolated enum ResultCellPresentation {
    static func alignment(for kind: ResultGridValueKind) -> NSTextAlignment {
        switch kind {
        case .numeric, .temporal: .right
        case .boolean: .center
        default: .left
        }
    }

    /// Whether the kind's digits should line up down a column.
    static func usesTabularDigits(_ kind: ResultGridValueKind) -> Bool {
        kind == .numeric || kind == .temporal
    }

    static let trueSymbol = "✓"
    static let falseSymbol = "✗"

    /// The text a cell shows for `raw`. Booleans become ✓ or ✗; anything unrecognised stays as is.
    static func displayText(_ raw: String?, kind: ResultGridValueKind) -> String {
        guard let raw else { return kind == .null ? "NULL" : "" }
        guard kind == .boolean else { return raw }
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "t", "1", "yes", "y", "on": return trueSymbol
        case "false", "f", "0", "no", "n", "off": return falseSymbol
        default: return raw
        }
    }
}
#endif
