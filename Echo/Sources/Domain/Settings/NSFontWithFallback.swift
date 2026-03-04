import SwiftUI

struct NSFontWithFallback {
    var name: String
    var size: CGFloat
    var ligaturesEnabled: Bool

    init(name: String, size: CGFloat, ligaturesEnabled: Bool = true) {
        self.name = name
        self.size = size
        self.ligaturesEnabled = ligaturesEnabled
    }

#if os(macOS)
    var font: NSFont {
        if SQLEditorTheme.isSystemFontIdentifier(name) {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let custom = NSFont(name: name, size: size) {
            return custom
        }
        if let fallback = NSFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return fallback
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#else
    var font: UIFont {
        if SQLEditorTheme.isSystemFontIdentifier(name) {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let custom = UIFont(name: name, size: size) {
            return custom
        }
        if let fallback = UIFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return fallback
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#endif
}
