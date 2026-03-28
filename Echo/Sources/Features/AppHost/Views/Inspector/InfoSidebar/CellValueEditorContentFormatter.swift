import Foundation
import UniformTypeIdentifiers

enum CellValueEditorContentFormatter {
    static func displayValue(for content: CellValueInspectorContent) -> String {
        guard content.valueKind == .json else { return content.rawValue }
        guard let data = content.rawValue.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: formatted, encoding: .utf8)
        else {
            return content.rawValue
        }
        return string
    }

    static func suggestedFileName(for content: CellValueInspectorContent) -> String {
        let baseName = sanitizedFileComponent(content.columnName.isEmpty ? "cell-value" : content.columnName)
        return "\(baseName).\(suggestedFileExtension(for: content))"
    }

    static func suggestedFileExtension(for content: CellValueInspectorContent) -> String {
        switch content.valueKind {
        case .json:
            return "json"
        case .binary:
            return "bin"
        default:
            return "txt"
        }
    }

    static func contentTypes(for content: CellValueInspectorContent) -> [UTType] {
        switch content.valueKind {
        case .json:
            return [.json, .plainText]
        case .binary:
            return [.data]
        default:
            return [.plainText]
        }
    }

    private static func sanitizedFileComponent(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(scalars).replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "cell-value" : trimmed
    }
}
