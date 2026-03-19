import SwiftUI
import AppKit

// MARK: - Shortcut Row

struct ShortcutRowView: View {
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
        PropertyRow(title: item.title) {
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
                .fill(ColorTokens.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ColorTokens.accent.opacity(0.4), lineWidth: 1)
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

struct ShortcutKeyCap: View {
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
                    .strokeBorder(isActive ? ColorTokens.accent.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .opacity(isDimmed ? 0.5 : 1.0)
    }
}

struct ShortcutKeyCaps: View {
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
