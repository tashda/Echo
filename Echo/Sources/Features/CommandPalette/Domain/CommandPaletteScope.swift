import Foundation

/// What the ⌘K palette lists. Typing "Tab Overview" (or ⇧⌘O) turns it to this window's tabs
/// (round 35.1, TO6).
enum CommandPaletteScope: Equatable {
    case everything
    case tabs
}
