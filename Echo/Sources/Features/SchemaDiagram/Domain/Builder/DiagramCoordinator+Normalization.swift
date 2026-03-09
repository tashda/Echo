import Foundation

extension DiagramCoordinator {
    func normalize(_ identifier: String, fallbackSchema: String) -> DiagramTableKey {
        func clean(_ raw: String) -> String {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            func stripWrapping(_ prefix: Character, _ suffix: Character) {
                if value.count >= 2, value.first == prefix, value.last == suffix {
                    value.removeFirst()
                    value.removeLast()
                }
            }
            let wrappers: [(Character, Character)] = [("\"", "\""), ("`", "`"), ("[", "]")]
            for (start, end) in wrappers where value.first == start && value.last == end {
                stripWrapping(start, end)
                break
            }
            value = value.replacingOccurrences(of: "\"\"", with: "\"")
            return value
        }

        func splitComponents(_ identifier: String) -> [String] {
            guard !identifier.isEmpty else { return [] }
            var components: [String] = []
            var current = ""
            var activeQuote: Character?
            var bracketDepth = 0
            var index = identifier.startIndex
            while index < identifier.endIndex {
                let char = identifier[index]
                switch char {
                case "\"":
                    current.append(char)
                    if activeQuote == "\"" {
                        let nextIndex = identifier.index(after: index)
                        if nextIndex < identifier.endIndex && identifier[nextIndex] == "\"" {
                            current.append(identifier[nextIndex])
                            index = nextIndex
                        } else { activeQuote = nil }
                    } else if activeQuote == nil { activeQuote = "\"" }
                case "`":
                    current.append(char)
                    if activeQuote == "`" { activeQuote = nil }
                    else if activeQuote == nil { activeQuote = "`" }
                case "[":
                    bracketDepth += 1
                    current.append(char)
                case "]":
                    if bracketDepth > 0 { bracketDepth -= 1 }
                    current.append(char)
                case "." where activeQuote == nil && bracketDepth == 0:
                    components.append(current)
                    current = ""
                default:
                    current.append(char)
                }
                index = identifier.index(after: index)
            }
            components.append(current)
            return components.filter { !$0.isEmpty }
        }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = splitComponents(trimmed)
        if components.count >= 2 {
            let schemaComponent = components[components.count - 2]
            let tableComponent = components[components.count - 1]
            return DiagramTableKey(schema: clean(schemaComponent), name: clean(tableComponent))
        } else if let single = components.first {
            return DiagramTableKey(schema: fallbackSchema, name: clean(single))
        } else {
            return DiagramTableKey(schema: fallbackSchema, name: clean(trimmed))
        }
    }
}
