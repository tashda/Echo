import Foundation

/// One of the server colours: a name and how it looks in light and in dark appearance, so it holds
/// on both (round 50, PC3).
nonisolated struct ServerColor: Sendable, Equatable, Identifiable {
    let name: String
    let light: UInt32
    let dark: UInt32

    var id: String { name }
    /// What is saved on the connection (`SavedConnection.colorHex`): the light colour, six digits.
    var lightHex: String { String(format: "%06X", light) }

    func value(isDark: Bool) -> UInt32 { isDark ? dark : light }
}

/// The thirty colours a server can have (round 50, PC3); the colour well offers any other. A
/// palette colour is saved as its light hex, the same string a custom colour uses, so saved and
/// synced connections need no new field; its dark twin is found by looking the hex up. Anything not
/// in the palette (the five colours earlier builds offered, or a colour from the well) is drawn as
/// saved, in both appearances.
nonisolated enum ServerColorPalette {
    static let all: [ServerColor] = [
        ServerColor(name: "Crimson", light: 0xC62F3B, dark: 0xFF5A67),
        ServerColor(name: "Vermilion", light: 0xE2492B, dark: 0xFF7452),
        ServerColor(name: "Tangerine", light: 0xEF7A1A, dark: 0xFF9A3D),
        ServerColor(name: "Amber", light: 0xE5A100, dark: 0xFFC433),
        ServerColor(name: "Gold", light: 0xB8962E, dark: 0xE3C45B),
        ServerColor(name: "Lime", light: 0x7DAF1C, dark: 0xA6D94A),
        ServerColor(name: "Fern", light: 0x3F9B4B, dark: 0x5FCB70),
        ServerColor(name: "Emerald", light: 0x0E9F6E, dark: 0x34D399),
        ServerColor(name: "Jade", light: 0x14917E, dark: 0x3EC9B2),
        ServerColor(name: "Teal", light: 0x0F8B94, dark: 0x3FC0CB),
        ServerColor(name: "Cyan", light: 0x1A9FD1, dark: 0x4CC9F5),
        ServerColor(name: "Sky", light: 0x3B8FE8, dark: 0x6FB3FF),
        ServerColor(name: "Azure", light: 0x2563EB, dark: 0x5B8DFF),
        ServerColor(name: "Cobalt", light: 0x3446C9, dark: 0x6C7CFF),
        ServerColor(name: "Indigo", light: 0x5B3FD1, dark: 0x8B7BFF),
        ServerColor(name: "Violet", light: 0x8A3FD1, dark: 0xB27BFF),
        ServerColor(name: "Orchid", light: 0xB03FC9, dark: 0xD77BF0),
        ServerColor(name: "Magenta", light: 0xD1318F, dark: 0xF56BBA),
        ServerColor(name: "Rose", light: 0xE0446A, dark: 0xFF7C9A),
        ServerColor(name: "Coral", light: 0xF0605D, dark: 0xFF8A85),
        ServerColor(name: "Terracotta", light: 0xB5563A, dark: 0xE08A6B),
        ServerColor(name: "Sand", light: 0xA88B5E, dark: 0xD6BD8E),
        ServerColor(name: "Moss", light: 0x6B7F3A, dark: 0xA1B86A),
        ServerColor(name: "Spruce", light: 0x2F6B55, dark: 0x5FA98C),
        ServerColor(name: "Steel", light: 0x4F6F8F, dark: 0x8FB0D0),
        ServerColor(name: "Slate", light: 0x5B6575, dark: 0x9AA5B8),
        ServerColor(name: "Graphite", light: 0x3A3F47, dark: 0x8A929E),
        ServerColor(name: "Plum", light: 0x6B2E5E, dark: 0xB56AA6),
        ServerColor(name: "Burgundy", light: 0x7A1F32, dark: 0xC45A70),
        ServerColor(name: "Navy", light: 0x1D2F5C, dark: 0x5C78C4),
    ]

    /// The colour a new server starts with.
    static let defaultColor: ServerColor = all.first { $0.name == "Azure" } ?? all[0]

    /// A hex string without its "#" or any other mark, in capitals.
    static func normalised(_ hex: String) -> String {
        hex.filter { $0.isHexDigit }.uppercased()
    }

    /// The palette colour saved as `hex`, if it is one.
    static func color(forStored hex: String) -> ServerColor? {
        let key = normalised(hex)
        return all.first { $0.lightHex == key }
    }

    /// The name to say for a saved colour: the palette's, one of the five earlier colours', or nil.
    static func name(forStored hex: String) -> String? {
        if let match = color(forStored: hex) { return match.name }
        return legacyNames[normalised(hex)]
    }

    /// The colours the connection sheet offered before the palette; they still draw as saved.
    static let legacyNames: [String: String] = [
        "5A9CDE": "Blue", "6EAE72": "Green", "E8943A": "Orange", "9B72CF": "Purple", "D4687A": "Rose"
    ]

    /// Red, green and blue (0 to 1, sRGB) a saved colour has in this appearance; nil when `hex` is
    /// not a colour.
    static func components(forStored hex: String, isDark: Bool) -> (red: Double, green: Double, blue: Double)? {
        if let match = color(forStored: hex) { return components(of: match.value(isDark: isDark)) }
        guard let value = rgbValue(ofHex: hex) else { return nil }
        return components(of: value)
    }

    private static func components(of value: UInt32) -> (red: Double, green: Double, blue: Double) {
        (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// Three, six or eight (alpha first) hex digits as 0xRRGGBB.
    private static func rgbValue(ofHex hex: String) -> UInt32? {
        let digits = normalised(hex)
        guard let number = UInt32(digits, radix: 16) else { return nil }
        switch digits.count {
        case 3: return ((number >> 8) * 17) << 16 | ((number >> 4 & 0xF) * 17) << 8 | (number & 0xF) * 17
        case 6: return number
        case 8: return number & 0xFFFFFF
        default: return nil
        }
    }
}
