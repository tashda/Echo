#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func normalizeIdentifier(_ value: String) -> String {
        var identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = identifier.firstIndex(where: { $0.isWhitespace }) {
            identifier = String(identifier[..<spaceIndex])
        }
        identifier = identifier.trimmingCharacters(in: SQLTextView.identifierDelimiterCharacterSet)
        let removable: Set<Character> = ["\"", "'", "[", "]", "`"]
        identifier.removeAll(where: { removable.contains($0) })
        return identifier
    }

    internal func knownSourceNames() -> [String] {
        guard let context = completionContext, let structure = context.structure else { return [] }
        let selectedDatabase = context.selectedDatabase?.lowercased()
        var names: Set<String> = []

        for database in structure.databases {
            if let selectedDatabase, database.name.lowercased() != selectedDatabase { continue }
            for schema in database.schemas {
                for object in schema.objects where object.type == .table || object.type == .view || object.type == .materializedView {
                    names.insert(object.name)
                }
            }
        }

        return Array(names)
    }

    internal func cleanedKeyword(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return trimmed.uppercased()
    }

    internal func lastWord(in token: String) -> String? {
        guard let range = token.range(of: #"([^.]+)$"#, options: .regularExpression) else { return nil }
        return String(token[range])
    }
}
#endif
