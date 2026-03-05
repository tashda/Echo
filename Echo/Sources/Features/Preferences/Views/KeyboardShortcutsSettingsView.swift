import SwiftUI
import AppKit

struct KeyboardShortcutsSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    private let sections = ShortcutSectionData.defaults

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Reset All to Default") {
                    var settings = projectStore.globalSettings
                    settings.customKeyboardShortcuts = nil
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
                .buttonStyle(.bordered)
                .disabled(customShortcuts.isEmpty)
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.top, SpacingTokens.sm)

            Form {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            ShortcutRowView(
                                item: item,
                                customBinding: customShortcuts[item.id],
                                onRecord: { binding in
                                    var settings = projectStore.globalSettings
                                    var shortcuts = settings.customKeyboardShortcuts ?? [:]
                                    shortcuts[item.id] = binding
                                    settings.customKeyboardShortcuts = shortcuts
                                    Task { try? await projectStore.updateGlobalSettings(settings) }
                                },
                                onReset: {
                                    var settings = projectStore.globalSettings
                                    var shortcuts = settings.customKeyboardShortcuts ?? [:]
                                    shortcuts.removeValue(forKey: item.id)
                                    settings.customKeyboardShortcuts = shortcuts.isEmpty ? nil : shortcuts
                                    Task { try? await projectStore.updateGlobalSettings(settings) }
                                }
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } // VStack
    }
}

// MARK: - Shortcut Row

private struct ShortcutRowView: View {
    let item: ShortcutItemData
    let customBinding: CustomShortcutBinding?
    let onRecord: (CustomShortcutBinding) -> Void
    let onReset: () -> Void

    @State private var isRecording = false

    private var displayKeys: [String] {
        customBinding?.displayKeys ?? item.keys
    }

    private var isCustomized: Bool { customBinding != nil }

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xs) {
                if isRecording {
                    ShortcutRecorderField(
                        keys: displayKeys,
                        onRecord: { binding in
                            isRecording = false
                            onRecord(binding)
                        },
                        onCancel: {
                            isRecording = false
                        }
                    )
                } else {
                    ShortcutKeyCaps(keys: displayKeys, isCustomized: isCustomized)
                }

                if isCustomized && !isRecording {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if let context = item.context {
                    Text(context)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRecording { isRecording = true }
        }
    }
}

// MARK: - Shortcut Recorder

private struct ShortcutRecorderField: View {
    let keys: [String]
    let onRecord: (CustomShortcutBinding) -> Void
    let onCancel: () -> Void

    @State private var modifierKeys: [String] = []

    var body: some View {
        ShortcutRecorderRepresentable(
            onRecord: onRecord,
            onCancel: onCancel,
            onModifiersChanged: { modifierKeys = $0 }
        )
        .frame(width: 0, height: 0)
        .opacity(0)
        .overlay(alignment: .trailing) {
            HStack(spacing: SpacingTokens.xxs2) {
                if modifierKeys.isEmpty {
                    // Show existing keys grayed out + subtle dots
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                        keyCap(key, dimmed: true)
                    }
                    Text("…")
                        .font(TypographyTokens.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                } else {
                    // Show pressed modifiers as key caps + dots for remaining
                    ForEach(Array(modifierKeys.enumerated()), id: \.offset) { _, key in
                        keyCap(key, dimmed: false)
                    }
                    Text("…")
                        .font(TypographyTokens.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func keyCap(_ key: String, dimmed: Bool) -> some View {
        Text(key)
            .font(TypographyTokens.caption2.weight(.medium))
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(dimmed ? Color.clear : Color.accentColor, lineWidth: 1)
            )
            .opacity(dimmed ? 0.5 : 1.0)
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    let onRecord: (CustomShortcutBinding) -> Void
    let onCancel: () -> Void
    let onModifiersChanged: ([String]) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        view.onModifiersChanged = onModifiersChanged
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {}
}

final class ShortcutRecorderNSView: NSView {
    var onRecord: ((CustomShortcutBinding) -> Void)?
    var onCancel: (() -> Void)?
    var onModifiersChanged: (([String]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }

        let hasRequiredModifier = modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option)
        guard hasRequiredModifier else { return }

        let character = event.charactersIgnoringModifiers ?? ""
        let binding = CustomShortcutBinding(
            keyCode: Int(event.keyCode),
            character: character,
            modifiers: ShortcutModifiers(from: modifiers)
        )
        onRecord?(binding)
    }

    override func flagsChanged(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        onModifiersChanged?(parts)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 1, height: 1)
    }
}

// MARK: - Key Caps

private struct ShortcutKeyCaps: View {
    let keys: [String]
    var isCustomized: Bool = false

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(TypographyTokens.caption2.weight(.medium))
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.xxs2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)
                    )
            }
        }
        .opacity(isCustomized ? 1 : 0.8)
        .contentShape(Rectangle())
    }
}

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

private struct ShortcutSectionData: Identifiable {
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
                .init(title: "Show Tab Overview", context: "Toggle the tab overview switcher.", keys: ["⌘", "O"]),
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
                .init(title: "Open Manage Connections", context: "Open the Manage Connections window.", keys: ["⌘", "⇧", "M"])
            ]
        )
    ]
}

private struct ShortcutItemData: Identifiable {
    let title: String
    let context: String?
    let keys: [String]

    var id: String { title }
}
