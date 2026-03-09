import Foundation

enum AliasGenerator {
    static func shortcut(for name: String) -> String? {
        let components = name.split { !$0.isLetter && !$0.isNumber }
        var result: [Character] = []
        for component in components where !component.isEmpty {
            if let first = component.first {
                result.append(Character(first.lowercased()))
            }
            for scalar in component.unicodeScalars.dropFirst() {
                if CharacterSet.uppercaseLetters.contains(scalar) {
                    result.append(Character(String(scalar).lowercased()))
                }
            }
        }

        if !result.isEmpty {
            return String(result)
        }

        let trimmed = name.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !trimmed.isEmpty else { return nil }
        let fallback = trimmed.prefix(3).map { Character(String($0).lowercased()) }
        return fallback.isEmpty ? nil : String(fallback)
    }
}
