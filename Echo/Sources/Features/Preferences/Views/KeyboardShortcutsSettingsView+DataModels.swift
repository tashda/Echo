import SwiftUI
import AppKit

// MARK: - Data Models

struct CustomShortcutBinding: Codable, Hashable {
    let keyCode: Int
    let character: String
    let modifiers: ShortcutModifiers

    var displayKeys: [String] {
        var parts: [String] = []
        if modifiers.control { parts.append("⌃") }
        if modifiers.option { parts.append("⌥") }
        if modifiers.shift { parts.append("⇧") }
        if modifiers.command { parts.append("⌘") }

        let keyLabel = Self.keyCodeLabel(keyCode, character: character)
        parts.append(keyLabel)
        return parts
    }

    var swiftUIKey: KeyEquivalent {
        switch keyCode {
        case 36: return .return
        case 48: return .tab
        case 49: return .space
        case 51: return .delete
        case 53: return .escape
        case 123: return .leftArrow
        case 124: return .rightArrow
        case 125: return .downArrow
        case 126: return .upArrow
        default:
            let ch = character.lowercased()
            return KeyEquivalent(ch.isEmpty ? Character("?") : ch.first!)
        }
    }

    var swiftUIModifiers: EventModifiers {
        var mods: EventModifiers = []
        if modifiers.command { mods.insert(.command) }
        if modifiers.shift { mods.insert(.shift) }
        if modifiers.option { mods.insert(.option) }
        if modifiers.control { mods.insert(.control) }
        return mods
    }

    private static func keyCodeLabel(_ keyCode: Int, character: String) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            let upper = character.uppercased()
            return upper.isEmpty ? "Key\(keyCode)" : upper
        }
    }
}

struct ShortcutModifiers: Codable, Hashable {
    var command: Bool = false
    var shift: Bool = false
    var option: Bool = false
    var control: Bool = false

    init(command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    init(from flags: NSEvent.ModifierFlags) {
        self.command = flags.contains(.command)
        self.shift = flags.contains(.shift)
        self.option = flags.contains(.option)
        self.control = flags.contains(.control)
    }
}

// MARK: - Shortcut Section/Item Data

struct ShortcutSectionData: Identifiable {
    let title: String
    let items: [ShortcutItemData]

    var id: String { title }

    static let defaults: [ShortcutSectionData] = [
        ShortcutSectionData(
            title: "Workspace",
            items: [
                .init(title: "New Query Tab", context: "Open a new SQL editing tab.", keys: ["⌘", "T"]),
                .init(title: "Next Tab", context: "Switch to the next workspace tab.", keys: ["⌃", "⇥"]),
                .init(title: "Previous Tab", context: "Switch to the previous workspace tab.", keys: ["⌃", "⇧", "⇥"]),
                .init(title: "Show Tab Overview", context: "Toggle the tab overview switcher.", keys: ["⌘", "⇧", "O"]),
                .init(title: "Close Query Tab", context: "Close the active tab.", keys: ["⌘", "W"]),
                .init(title: "Reopen Closed Tab", context: "Restore the most recently closed tab.", keys: ["⌘", "⇧", "T"])
            ]
        ),
        ShortcutSectionData(
            title: "Query Editing",
            items: [
                .init(title: "Run Selected Query", context: "Execute the highlighted SQL in the query editor.", keys: ["⌘", "Return"]),
                .init(title: "Format Query", context: "Format the current SQL using the configured style.", keys: ["⌘", "⇧", "F"]),
                .init(title: "Show EchoSense Suggestions", context: "Reopen the EchoSense popover after dismissal.", keys: ["⌘", "."]),
                .init(title: "Manual EchoSense Trigger", context: "Force suggestions even when auto-popup is suppressed.", keys: ["Ctrl", "Space"])
            ]
        ),
        ShortcutSectionData(
            title: "Results Grid",
            items: [
                .init(title: "Copy Selection", context: "Copy the selected cells.", keys: ["⌘", "C"]),
                .init(title: "Copy with Headers", context: "Include column headers with the copied cells.", keys: ["⌘", "⇧", "C"])
            ]
        ),
        ShortcutSectionData(
            title: "Connections",
            items: [
                .init(title: "Manage Connections", context: "Open the Manage Connections window.", keys: ["⌘", "⇧", "M"])
            ]
        )

    ]
}

struct ShortcutItemData: Identifiable {
    let title: String
    let context: String?
    let keys: [String]
    let isDead: Bool

    var id: String { title }

    init(title: String, context: String? = nil, keys: [String], isDead: Bool = false) {
        self.title = title
        self.context = context
        self.keys = keys
        self.isDead = isDead
    }
}
