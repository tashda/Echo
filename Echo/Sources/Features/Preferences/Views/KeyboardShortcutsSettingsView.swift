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
                                        .fill(ColorTokens.accent.opacity(highlightOpacity))
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
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset All") {
                    var settings = projectStore.globalSettings
                    settings.customKeyboardShortcuts = nil
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
                .disabled(customShortcuts.isEmpty)
                .help("Reset all keyboard shortcuts to their default values.")
            }
        }
    }
}

