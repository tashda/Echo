import Foundation

/// A symbol or an emoji the user chose for a server (round 51, CU2). It replaces the letters in
/// the server trail, the connection list and the connection sheet; with none chosen the letters
/// stay. It is stored on the connection as two optional fields, so older saved data and older
/// synced copies decode as "automatic".
nonisolated enum ServerRailGlyph: Hashable, Sendable {
    case symbol(String)
    case emoji(String)

    /// The symbols the customise controls offer (SF Symbols that exist on macOS 26).
    static let symbols = [
        "cylinder.fill", "bolt.fill", "flame.fill", "leaf.fill", "shield.fill", "star.fill",
        "moon.fill", "cloud.fill", "hammer.fill", "flag.fill", "gearshape.fill", "building.2.fill"
    ]

    /// The emoji the customise controls offer.
    static let emoji = ["🐘", "🐬", "🚀", "🔥", "🧪", "🏭", "🎯", "🌍"]

    /// The glyph for the two stored fields. Blank values count as unset; a symbol wins over an
    /// emoji if a damaged copy holds both.
    init?(symbol: String?, emoji: String?) {
        if let symbol = symbol?.trimmingCharacters(in: .whitespacesAndNewlines), !symbol.isEmpty {
            self = .symbol(symbol)
        } else if let emoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
            self = .emoji(emoji)
        } else {
            return nil
        }
    }

    /// The stored fields for a glyph, or both nil for automatic.
    static func storedFields(of glyph: ServerRailGlyph?) -> (symbol: String?, emoji: String?) {
        switch glyph {
        case .symbol(let name)?: (name, nil)
        case .emoji(let value)?: (nil, value)
        case nil: (nil, nil)
        }
    }
}

extension SavedConnection {
    /// The symbol or emoji chosen for this server, if any. Setting one clears the other.
    nonisolated var railGlyph: ServerRailGlyph? {
        get { ServerRailGlyph(symbol: railSymbol, emoji: railEmoji) }
        set { (railSymbol, railEmoji) = ServerRailGlyph.storedFields(of: newValue) }
    }
}
