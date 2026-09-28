import Foundation

/// Derives the short label shown for a server in the rail.
///
/// - Two or more words ("postgres_services", "prod-eu-pg01") use the first letter of the first two words.
/// - A single word ending in two or more digits ("postgres18") uses those digits, so numbered servers stay distinct.
/// - Purely numeric names such as IP addresses use the last component ("192.168.1.20" → "20").
/// - Anything else uses its first two letters.
enum ServerRailMonogram {
    static func make(from name: String) -> String {
        let words = name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        guard let first = words.first else { return "?" }

        if words.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return String(words.last!.suffix(2))
        }

        if words.count >= 2 {
            return (String(first.prefix(1)) + String(words[1].prefix(1))).uppercased()
        }

        let trailingDigits = first.reversed().prefix(while: \.isNumber)
        if trailingDigits.count >= 2 {
            return String(String(trailingDigits.reversed()).suffix(2))
        }

        return String(first.prefix(2)).uppercased()
    }
}
