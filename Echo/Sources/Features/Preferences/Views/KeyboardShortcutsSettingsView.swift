import SwiftUI
import AppKit

struct KeyboardShortcutsSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    private let sections = ShortcutSectionData.defaults

    @State private var highlightedSectionID: String?
    @State private var highlightOpacity: Double = 0

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

            ScrollViewReader { proxy in
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
                        .id(section.id)
                        .background(
                            Group {
                                if highlightedSectionID == section.id {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.accentColor.opacity(highlightOpacity))
                                        .padding(-SpacingTokens.xxs2)
                                }
                            }
                        )
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .onReceive(NotificationCenter.default.publisher(for: .highlightSettingsGroup)) { notification in
                    guard let sectionTitle = notification.object as? String else { return }
                    proxy.scrollTo(sectionTitle, anchor: .center)
                    highlightedSectionID = sectionTitle
                    highlightOpacity = 0
                    // Smooth pulse 3 times
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        for _ in 0..<3 {
                            withAnimation(.easeInOut(duration: 0.35)) { highlightOpacity = 0.18 }
                            try? await Task.sleep(for: .milliseconds(400))
                            withAnimation(.easeInOut(duration: 0.35)) { highlightOpacity = 0 }
                            try? await Task.sleep(for: .milliseconds(400))
                        }
                        highlightedSectionID = nil
                    }
                }
            }
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
                        .contextMenu {
                            if isCustomized {
                                Button("Revert to Default") {
                                    onReset()
                                }
                            }
                        }
                }
            }
        } label: {
            Text(item.title)
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

    @State private var currentModifiers: [String] = []
    @State private var recordedKeys: [String]?

    private var displayedKeys: [String] {
        if let recorded = recordedKeys { return recorded }
        if !currentModifiers.isEmpty { return currentModifiers }
        return keys
    }

    private var isActive: Bool {
        !currentModifiers.isEmpty || recordedKeys != nil
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(Array(displayedKeys.enumerated()), id: \.offset) { _, key in
                ShortcutKeyCap(
                    key: key,
                    isActive: isActive,
                    isDimmed: currentModifiers.isEmpty && recordedKeys == nil
                )
            }

        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxs2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
        .background {
            ShortcutRecorderRepresentable(
                onRecord: onRecord,
                onCancel: onCancel,
                onModifiersChanged: { currentModifiers = $0 }
            )
            .frame(width: 1, height: 1)
            .opacity(0)
        }
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

    private var keyMonitor: Any?
    private var flagsMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        installMonitors()
    }

    override func removeFromSuperview() {
        removeMonitors()
        super.removeFromSuperview()
    }

    private func installMonitors() {
        // Local monitor intercepts key events before menu bar / responder chain
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if event.keyCode == 53 { // Escape
                self.onCancel?()
                return nil // consume event
            }

            let hasRequiredModifier = modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option)
            guard hasRequiredModifier else { return event }

            let character = event.charactersIgnoringModifiers ?? ""
            let binding = CustomShortcutBinding(
                keyCode: Int(event.keyCode),
                character: character,
                modifiers: ShortcutModifiers(from: modifiers)
            )
            self.onRecord?(binding)
            return nil // consume event — prevents menu bar from handling it
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var parts: [String] = []
            if mods.contains(.control) { parts.append("⌃") }
            if mods.contains(.option) { parts.append("⌥") }
            if mods.contains(.shift) { parts.append("⇧") }
            if mods.contains(.command) { parts.append("⌘") }
            self.onModifiersChanged?(parts)
            return event
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        keyMonitor = nil
        flagsMonitor = nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 1, height: 1)
    }
}

// MARK: - Key Cap Components

private struct ShortcutKeyCap: View {
    let key: String
    var isActive: Bool = false
    var isDimmed: Bool = false

    var body: some View {
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
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .opacity(isDimmed ? 0.5 : 1.0)
    }
}

private struct ShortcutKeyCaps: View {
    let keys: [String]
    var isCustomized: Bool = false

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                ShortcutKeyCap(key: key)
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
            title: "EchoSense",
            items: [
                .init(title: "Command + Period Trigger", context: "Toggle \u{2318}. as a manual EchoSense trigger.", keys: ["⌘", "."]),
                .init(title: "Control + Space Trigger", context: "Toggle Ctrl+Space as an alternative EchoSense trigger.", keys: ["⌃", "Space"])
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
