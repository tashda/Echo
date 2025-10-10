import Foundation
import SwiftUI
import Combine

// MARK: - Keyboard Shortcuts Configuration

@MainActor
final class KeyboardShortcutsManager: ObservableObject {
    @Published var shortcuts: KeyboardShortcuts = KeyboardShortcuts()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "keyboardShortcuts"

    init() {
        loadShortcuts()
    }

    func loadShortcuts() {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(KeyboardShortcuts.self, from: data) {
            shortcuts = decoded
        }
    }

    func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }

    func resetToDefaults() {
        shortcuts = KeyboardShortcuts()
        saveShortcuts()
    }
}

struct KeyboardShortcuts: Codable {
    // Server Management
    #if os(macOS)
    var showServerSwitcher: ShortcutKey = ShortcutKey(key: "Tab", modifiers: [.command])
    var nextServer: ShortcutKey = ShortcutKey(key: "Tab", modifiers: [.command])
    var previousServer: ShortcutKey = ShortcutKey(key: "Tab", modifiers: [.command, .shift])
    var connectToServer: ShortcutKey = ShortcutKey(key: "Return", modifiers: [.command])
    var disconnectFromServer: ShortcutKey = ShortcutKey(key: "D", modifiers: [.command, .shift])
    #else
    var showServerSwitcher: ShortcutKey = ShortcutKey(key: "S", modifiers: [.command])
    var nextServer: ShortcutKey = ShortcutKey(key: "Right", modifiers: [.command])
    var previousServer: ShortcutKey = ShortcutKey(key: "Left", modifiers: [.command])
    var connectToServer: ShortcutKey = ShortcutKey(key: "Return", modifiers: [.command])
    var disconnectFromServer: ShortcutKey = ShortcutKey(key: "D", modifiers: [.command])
    #endif

    // Query Management
    var newQueryTab: ShortcutKey = ShortcutKey(key: "T", modifiers: [.command])
    var closeQueryTab: ShortcutKey = ShortcutKey(key: "W", modifiers: [.command])
    var nextQueryTab: ShortcutKey = ShortcutKey(key: "Tab", modifiers: [.control])
    var previousQueryTab: ShortcutKey = ShortcutKey(key: "Tab", modifiers: [.control, .shift])
    var executeQuery: ShortcutKey = ShortcutKey(key: "Return", modifiers: [.command])
    var saveQuery: ShortcutKey = ShortcutKey(key: "S", modifiers: [.command])
    var toggleTabOverview: ShortcutKey = ShortcutKey(key: "O", modifiers: [.command])

    // Navigation
    var focusSidebar: ShortcutKey = ShortcutKey(key: "0", modifiers: [.command])
    var focusQueryEditor: ShortcutKey = ShortcutKey(key: "1", modifiers: [.command])
    var focusResults: ShortcutKey = ShortcutKey(key: "2", modifiers: [.command])
    var toggleSidebar: ShortcutKey = ShortcutKey(key: "S", modifiers: [.command, .option])

    // Database Operations
    var refreshSchema: ShortcutKey = ShortcutKey(key: "R", modifiers: [.command])
    var openTableInNewTab: ShortcutKey = ShortcutKey(key: "Return", modifiers: [.command, .option])

    // General
    var showPreferences: ShortcutKey = ShortcutKey(key: ",", modifiers: [.command])
    var showHelp: ShortcutKey = ShortcutKey(key: "?", modifiers: [.command])
    var quit: ShortcutKey = ShortcutKey(key: "Q", modifiers: [.command])
}

struct ShortcutKey: Codable, Hashable {
    let key: String
    let modifiers: Set<KeyModifier>

    var displayString: String {
        let modifierStrings = modifiers.sorted { $0.sortOrder < $1.sortOrder }.map { $0.symbol }
        return (modifierStrings + [key]).joined()
    }

    var keyEquivalent: KeyEquivalent {
        switch key.lowercased() {
        case "tab":
            return KeyEquivalent.tab
        case "return", "enter":
            return KeyEquivalent.return
        case "escape":
            return KeyEquivalent.escape
        case "space":
            return KeyEquivalent.space
        case "delete":
            return KeyEquivalent.delete
        case "deleteforward":
            return KeyEquivalent.deleteForward
        case "home":
            return KeyEquivalent.home
        case "end":
            return KeyEquivalent.end
        case "pageup":
            return KeyEquivalent.pageUp
        case "pagedown":
            return KeyEquivalent.pageDown
        case "clear":
            return KeyEquivalent.clear
        case "left":
            return KeyEquivalent.leftArrow
        case "right":
            return KeyEquivalent.rightArrow
        case "up":
            return KeyEquivalent.upArrow
        case "down":
            return KeyEquivalent.downArrow
        default:
            // For single characters, get the first character
            if let firstChar = key.lowercased().first {
                return KeyEquivalent(firstChar)
            } else {
                // Fallback to a safe default
                return KeyEquivalent("a")
            }
        }
    }

    var eventModifiers: EventModifiers {
        var eventMods: EventModifiers = []
        if modifiers.contains(.command) { eventMods.insert(.command) }
        if modifiers.contains(.option) { eventMods.insert(.option) }
        if modifiers.contains(.control) { eventMods.insert(.control) }
        if modifiers.contains(.shift) { eventMods.insert(.shift) }
        return eventMods
    }
}

enum KeyModifier: String, CaseIterable, Codable, Hashable {
    case command = "cmd"
    case option = "opt"
    case control = "ctrl"
    case shift = "shift"

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    var displayName: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }

    var sortOrder: Int {
        switch self {
        case .control: return 0
        case .option: return 1
        case .shift: return 2
        case .command: return 3
        }
    }
}

// MARK: - Shortcut Recording View

struct ShortcutRecordingView: View {
    @Binding var shortcut: ShortcutKey
    @State private var isRecording = false
    @State private var recordedModifiers: Set<KeyModifier> = []
    @State private var recordedKey: String = ""

    var body: some View {
        HStack {
            Button(action: startRecording) {
                HStack {
                    if isRecording {
                        Text("Press keys...")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(shortcut.displayString)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(minWidth: 80)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .onKeyPress { keyPress in
                if isRecording {
                    handleKeyPress(keyPress)
                    return .handled
                }
                return .ignored
            }

            if isRecording {
                Button("Cancel") {
                    stopRecording()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func startRecording() {
        isRecording = true
        recordedModifiers = []
        recordedKey = ""
    }

    private func stopRecording() {
        isRecording = false
        recordedModifiers = []
        recordedKey = ""
    }

    private func handleKeyPress(_ keyPress: KeyPress) {
        // This is a simplified implementation
        // In a real app, you'd need to handle the actual key recording logic
        // For now, we'll just stop recording
        stopRecording()
    }
}

// MARK: - Shortcut Settings View

struct KeyboardShortcutsSettingsView: View {
    @ObservedObject var shortcutsManager: KeyboardShortcutsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(12)
                            .background {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keyboard Shortcuts")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Customize keyboard shortcuts for common actions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Shortcut Sections
                Form {
                    shortcutSection("Server Management", shortcuts: [
                        ("Show Server Switcher", $shortcutsManager.shortcuts.showServerSwitcher),
                        ("Next Server", $shortcutsManager.shortcuts.nextServer),
                        ("Previous Server", $shortcutsManager.shortcuts.previousServer),
                        ("Connect to Server", $shortcutsManager.shortcuts.connectToServer),
                        ("Disconnect from Server", $shortcutsManager.shortcuts.disconnectFromServer)
                    ])

                    shortcutSection("Query Management", shortcuts: [
                        ("New Query Tab", $shortcutsManager.shortcuts.newQueryTab),
                        ("Close Query Tab", $shortcutsManager.shortcuts.closeQueryTab),
                        ("Toggle Tab Overview", $shortcutsManager.shortcuts.toggleTabOverview),
                        ("Next Query Tab", $shortcutsManager.shortcuts.nextQueryTab),
                        ("Previous Query Tab", $shortcutsManager.shortcuts.previousQueryTab),
                        ("Execute Query", $shortcutsManager.shortcuts.executeQuery),
                        ("Save Query", $shortcutsManager.shortcuts.saveQuery)
                    ])

                    shortcutSection("Navigation", shortcuts: [
                        ("Focus Sidebar", $shortcutsManager.shortcuts.focusSidebar),
                        ("Focus Query Editor", $shortcutsManager.shortcuts.focusQueryEditor),
                        ("Focus Results", $shortcutsManager.shortcuts.focusResults),
                        ("Toggle Sidebar", $shortcutsManager.shortcuts.toggleSidebar)
                    ])

                    shortcutSection("Database Operations", shortcuts: [
                        ("Refresh Schema", $shortcutsManager.shortcuts.refreshSchema),
                        ("Open Table in New Tab", $shortcutsManager.shortcuts.openTableInNewTab)
                    ])

                    shortcutSection("General", shortcuts: [
                        ("Show Preferences", $shortcutsManager.shortcuts.showPreferences),
                        ("Show Help", $shortcutsManager.shortcuts.showHelp),
                        ("Quit", $shortcutsManager.shortcuts.quit)
                    ])
                }
                .formStyle(.grouped)
            }
            .padding(32)
        }
        .navigationTitle("Keyboard Shortcuts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    shortcutsManager.saveShortcuts()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Reset to Defaults") {
                    shortcutsManager.resetToDefaults()
                }
            }
        }
    }

    @ViewBuilder
    private func shortcutSection(_ title: String, shortcuts: [(String, Binding<ShortcutKey>)]) -> some View {
        Section(header: Text(title)) {
            ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, shortcut in
                HStack {
                    Text(shortcut.0)
                    Spacer()
                    ShortcutRecordingView(shortcut: shortcut.1)
                }
            }
        }
    }
}
