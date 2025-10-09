import SwiftUI
import AppKit

/// Primary settings scene built with a native `NavigationSplitView`.
struct SettingsWindow: Scene {
    static let sceneID = "settings"

    var body: some Scene {
        Window("Settings", id: Self.sceneID) {
            SettingsView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
        .defaultSize(width: 720, height: 520)
    }
}

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance
        case applicationCache

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .applicationCache: return "Application Cache"
            }
        }

        var systemImage: String {
            switch self {
            case .appearance: return "paintbrush"
            case .applicationCache: return "internaldrive"
            }
        }
    }

    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var selection: SettingsSection? = .appearance

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if selection == nil {
                selection = .appearance
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            preferredColumn = .sidebar
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        .navigationDestination(for: SettingsSection.self) { section in
            sectionView(for: section)
                .navigationTitle(section.title)
        }
    }

    private var detailContent: some View {
        NavigationStack {
            if let selection {
                sectionView(for: selection)
                    .navigationTitle(selection.title)
            } else {
                ContentUnavailableView {
                    Label("Select a Section", systemImage: "slider.horizontal.3")
                } description: {
                    Text("Choose a settings category to view its options.")
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:
            AppearanceSettingsView()
                .environmentObject(appModel)
                .environmentObject(themeManager)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environmentObject(clipboardHistory)
        }
    }
}

#Preview("Settings Window") {
    SettingsView()
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var paletteDraft: SQLEditorPalette?
    @State private var isCreatingPalette = false
    @State private var paletteToDelete: SQLEditorPalette?
    @State private var isPersistingPalette = false

    var body: some View {
        Form {
            appearanceSection
            accentSection
            sqlEditorSection
            editorDisplaySection
            informationSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: paletteEditorPresentedBinding) {
            if paletteDraft != nil {
                PaletteEditorSheet(
                    palette: paletteDraftBinding,
                    isNew: isCreatingPalette,
                    isSaving: isPersistingPalette,
                    onCancel: closePaletteEditor,
                    onSave: handlePaletteSave
                )
                .frame(minWidth: 460, minHeight: 520)
            }
        }
        .alert("Delete Palette?", isPresented: deleteAlertBinding, presenting: paletteToDelete) { palette in
            Button("Delete", role: .destructive) {
                deletePalette(palette)
            }
            Button("Cancel", role: .cancel) {
                paletteToDelete = nil
            }
        } message: { palette in
            Text("Deleting \(palette.name) removes it from global settings. Projects using it will fall back to your default palette.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            ThemeSelectionView(selection: themeBinding)

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accentSection: some View {
        Section("Accent") {
            Toggle("Use connected server color as accent", isOn: useServerAccentBinding)
                .toggleStyle(.switch)

            Text("When enabled, highlights outside the editor adopt the active connection's color.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var sqlEditorSection: some View {
        Section {
            paletteList
                .padding(.vertical, 4)

            if isPersistingPalette {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            LabeledContent("Palette actions") {
                HStack(spacing: 8) {
                    Button("New Custom Palette…") {
                        createPalette(from: selectedPalette)
                    }

                    Button("Duplicate Selected", action: { duplicatePalette(selectedPalette) })

                    if selectedPalette.kind == .custom {
                        Button("Edit…", action: { editPalette(selectedPalette) })

                        Button("Delete…", role: .destructive) {
                            paletteToDelete = selectedPalette
                        }
                    }
                }
            }
        } header: {
            Text("Default SQL Editor Palette")
        } footer: {
            Text("Defaults are saved separately for light and dark appearances. Switch the theme to configure each, or set project overrides from the project manager.")
        }
    }

    private var editorDisplaySection: some View {
        Section("Editor Display") {
            Toggle("Show line numbers", isOn: showLineNumbersBinding)
                .toggleStyle(.switch)

            Toggle("Highlight instances of selected symbol", isOn: highlightSelectedSymbolBinding)
                .toggleStyle(.switch)

            Toggle("Enable auto completion", isOn: enableAutoCompletionBinding)
                .toggleStyle(.switch)

            LabeledContent("Highlight delay") {
                Stepper(value: highlightDelayBinding, in: 0...2, step: 0.05) {
                    Text(String(format: "%.2fs", appModel.globalSettings.editorHighlightDelay))
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .controlSize(.small)
            }

            LabeledContent("Line spacing") {
                Stepper(value: lineSpacingBinding, in: 1.0...2.0, step: 0.05) {
                    Text(lineSpacingLabel(for: appModel.globalSettings.defaultEditorLineHeight))
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .controlSize(.small)
            }

            Toggle("Wrap lines to editor width", isOn: wrapLinesBinding)
                .toggleStyle(.switch)

            if appModel.globalSettings.editorWrapLines {
                LabeledContent("Indent wrapped lines") {
                    Stepper(value: indentWrappedLinesBinding, in: 0...12) {
                        Text("\(appModel.globalSettings.editorIndentWrappedLines) spaces")
                            .monospacedDigit()
                            .frame(width: 100, alignment: .trailing)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var informationSection: some View {
        Section("Information") {
            Text("Changes apply immediately. Appearance will continue to follow macOS when using the System option.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var showLineNumbersBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorShowLineNumbers },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorShowLineNumbers = newValue } }
            }
        )
    }

    private var highlightSelectedSymbolBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorHighlightSelectedSymbol },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorHighlightSelectedSymbol = newValue } }
            }
        )
    }

    private var highlightDelayBinding: Binding<Double> {
        Binding(
            get: { appModel.globalSettings.editorHighlightDelay },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorHighlightDelay = newValue } }
            }
        )
    }

    private var enableAutoCompletionBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorEnableAutocomplete },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorEnableAutocomplete = newValue } }
            }
        )
    }

    private var lineSpacingBinding: Binding<Double> {
        Binding(
            get: { appModel.globalSettings.defaultEditorLineHeight },
            set: { newValue in
                let clamped = min(max(newValue, 1.0), 2.0)
                let rounded = (clamped * 100).rounded() / 100
                Task { await appModel.updateGlobalEditorDisplay { $0.defaultEditorLineHeight = rounded } }
            }
        )
    }

    private var wrapLinesBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorWrapLines },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorWrapLines = newValue } }
            }
        )
    }

    private var indentWrappedLinesBinding: Binding<Int> {
        Binding(
            get: { appModel.globalSettings.editorIndentWrappedLines },
            set: { newValue in
                Task { await appModel.updateGlobalEditorDisplay { $0.editorIndentWrappedLines = newValue } }
            }
        )
    }

    // MARK: - Helpers

    private func lineSpacingLabel(for value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value))x"
        }
        if abs((value * 10).rounded() - value * 10) < 0.0001 {
            return String(format: "%.1fx", value)
        }
        return String(format: "%.2fx", value)
    }

    private var availablePalettes: [SQLEditorPalette] {
        appModel.globalSettings.availablePalettes
    }

    private var activeTone: SQLEditorPalette.Tone {
        switch themeManager.currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return themeManager.activePaletteTone
        }
    }

    private var activeToneTitle: String {
        switch activeTone {
        case .light:
            return "Light Palettes"
        case .dark:
            return "Dark Palettes"
        }
    }

    private func palettes(for tone: SQLEditorPalette.Tone) -> [SQLEditorPalette] {
        availablePalettes.filter { $0.tone == tone }
    }

    @ViewBuilder
    private var paletteList: some View {
        let palettes = palettes(for: activeTone)
        if palettes.isEmpty {
            Text("No palettes available for this appearance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(activeToneTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if themeManager.currentTheme == .system {
                    Text("Following the system's current \(themeManager.activePaletteTone == .dark ? "dark" : "light") appearance.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(palettes) { palette in
                        PaletteCard(
                            palette: palette,
                            isSelected: palette.id == defaultPaletteID,
                            action: { selectPalette(palette, tone: activeTone) }
                        )
                    }
                }
            }
        }
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { themeManager.currentTheme },
            set: { newTheme in
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeManager.currentTheme = newTheme
                }
            }
        )
    }

    private var useServerAccentBinding: Binding<Bool> {
        Binding(
            get: { appModel.useServerColorAsAccent },
            set: { newValue in
                appModel.useServerColorAsAccent = newValue
                Task { await appModel.updateGlobalEditorDisplay { $0.useServerColorAsAccent = newValue } }
            }
        )
    }

    private var defaultPaletteID: String {
        appModel.globalSettings.defaultPaletteID(for: activeTone)
    }

    private var selectedPalette: SQLEditorPalette {
        appModel.globalSettings.defaultPalette(for: activeTone)
            ?? (activeTone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    private var paletteEditorPresentedBinding: Binding<Bool> {
        Binding(
            get: { paletteDraft != nil },
            set: { if !$0 { closePaletteEditor() } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { paletteToDelete != nil },
            set: { if !$0 { paletteToDelete = nil } }
        )
    }

    private var paletteDraftBinding: Binding<SQLEditorPalette> {
        Binding(
            get: { paletteDraft ?? selectedPalette.asCustomCopy() },
            set: { paletteDraft = $0 }
        )
    }

    private func closePaletteEditor() {
        paletteDraft = nil
        isCreatingPalette = false
    }

    private func selectPalette(_ palette: SQLEditorPalette, tone: SQLEditorPalette.Tone) {
        Task {
            isPersistingPalette = true
            await appModel.setDefaultEditorPalette(to: palette.id, for: tone)
            await MainActor.run { isPersistingPalette = false }
        }
    }

    private func editPalette(_ palette: SQLEditorPalette) {
        paletteDraft = palette
        isCreatingPalette = false
    }

    private func duplicatePalette(_ palette: SQLEditorPalette) {
        createPalette(from: palette)
    }

    private func createPalette(from palette: SQLEditorPalette) {
        paletteDraft = palette.asCustomCopy(named: "\(palette.name) Copy")
        isCreatingPalette = true
    }

    private func handlePaletteSave(_ palette: SQLEditorPalette) {
        let tone = activeTone
        Task {
            isPersistingPalette = true
            await appModel.upsertCustomPalette(palette)
            if isCreatingPalette {
                await appModel.setDefaultEditorPalette(to: palette.id, for: tone)
            }
            await MainActor.run {
                closePaletteEditor()
                isPersistingPalette = false
            }
        }
    }

    private func deletePalette(_ palette: SQLEditorPalette) {
        Task {
            isPersistingPalette = true
            await appModel.deleteCustomPalette(withID: palette.id)
            await MainActor.run {
                paletteToDelete = nil
                isPersistingPalette = false
            }
        }
    }
}

struct ApplicationCacheSettingsView: View {
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @State private var confirmDisableHistory = false

    private let baseStorageOptions: [Int] = [
        256 * 1_024 * 1_024,
        512 * 1_024 * 1_024,
        1 * 1_024 * 1_024 * 1_024,
        2 * 1_024 * 1_024 * 1_024,
        5 * 1_024 * 1_024 * 1_024,
        10 * 1_024 * 1_024 * 1_024
    ]

    var body: some View {
        let store = clipboardHistory

        Form {
            Section("Clipboard History") {
                Toggle("Enable clipboard history", isOn: clipboardEnabledBinding(for: store))
                    .toggleStyle(.switch)

                Text("Echo stores recently copied queries and results locally for quick reuse. Data stays on this Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !store.isEnabled {
                    Text("History capture is disabled. Re-enable it to keep new copies.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }

            if store.isEnabled {
                storageLimitSection(for: store)
                storageLocationSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Disable Clipboard History?", isPresented: $confirmDisableHistory) {
            Button("Disable", role: .destructive) {
                confirmDisableHistory = false
                store.setEnabled(false)
            }

            Button("Cancel", role: .cancel) {
                confirmDisableHistory = false
            }
        } message: {
            Text("Echo will immediately delete all saved clipboard items. This action cannot be undone.")
        }
    }

    private func storageLimitSection(for store: ClipboardHistoryStore) -> some View {
        let usage = store.formattedUsageBreakdown()
        let options = storageOptions(for: store.storageLimit)

        return Section("Storage Limit") {
            Picker("Maximum storage", selection: storageLimitBinding(for: store)) {
                ForEach(options, id: \.self) { value in
                    Text(ClipboardHistoryStore.formatByteCount(value))
                        .tag(value)
                }
            }
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 8) {
                Text("Clipboard items persist until the storage limit is reached or you uninstall Echo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                usageView(usage)
            }
            .padding(.top, 8)
        }
    }

    private var storageLocationSection: some View {
        Section("Storage Location") {
            Button(action: openHistoryFolder) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(historyDirectoryDisplayPath)
                            .font(.system(size: 12, weight: .semibold))
                            .textSelection(.enabled)

                        Text("Open this folder in Finder to inspect or remove files manually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private var historyDirectoryURL: URL {
        let fm = FileManager.default
        let baseSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseSupport
            .appendingPathComponent("Echo", isDirectory: true)
            .appendingPathComponent("ClipboardHistory", isDirectory: true)
    }

    private var historyDirectoryDisplayPath: String {
        let fullPath = historyDirectoryURL.path
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if fullPath.hasPrefix(homePath) {
            let suffix = fullPath.dropFirst(homePath.count)
            return "~" + suffix
        }
        return fullPath
    }

    private func openHistoryFolder() {
        let url = historyDirectoryURL
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func clipboardEnabledBinding(for store: ClipboardHistoryStore) -> Binding<Bool> {
        Binding(
            get: { store.isEnabled },
            set: { newValue in
                if newValue {
                    store.setEnabled(true)
                } else {
                    confirmDisableHistory = true
                }
            }
        )
    }

    private func storageLimitBinding(for store: ClipboardHistoryStore) -> Binding<Int> {
        Binding(
            get: { store.storageLimit },
            set: { store.updateStorageLimit($0) }
        )
    }

    private func storageOptions(for limit: Int) -> [Int] {
        var options = baseStorageOptions
        if !options.contains(limit) {
            options.append(limit)
            options.sort()
        }
        return options
    }

    private func usageView(_ usageBreakdown: (total: String, query: String, grid: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Used Total") {
                Text(usageBreakdown.total)
                    .monospacedDigit()
            }

            LabeledContent("Queries") {
                Text(usageBreakdown.query)
                    .monospacedDigit()
            }

            LabeledContent("Grid Data") {
                Text(usageBreakdown.grid)
                    .monospacedDigit()
            }
        }
    }
}

private struct PaletteEditorSheet: View {
    @Binding var palette: SQLEditorPalette
    let isNew: Bool
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: (SQLEditorPalette) -> Void

    private var title: String { isNew ? "Create Palette" : "Edit Palette" }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Adjust colors for tokens, gutter, and background. Changes apply globally when saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PaletteEditorView(palette: $palette)

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: { onSave(palette) }) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(isNew ? "Create Palette" : "Save Changes")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || palette.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

// Legacy card views replaced by list-style controls for a more native macOS experience.

private struct ThemeSelectionView: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 14) {
            ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                ThemeOptionCard(theme: theme, isSelected: selection == theme) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selection = theme
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ThemePreview(style: theme.previewStyle, isActive: isSelected)
                    .frame(height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: theme.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(theme.previewStyle.contentForeground)
                        Text(theme.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.previewStyle.contentForeground)
                        Spacer(minLength: 4)
                        if isSelected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tint)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(theme.previewStyle.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.previewStyle.contentForeground.opacity(0.7))
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(width: 158)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.previewStyle.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : theme.previewStyle.stroke, lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: theme.previewStyle.shadow.opacity(isSelected ? 0.4 : 0.2), radius: isSelected ? 10 : 6, y: isSelected ? 6 : 3)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct ThemePreview: View {
    let style: ThemePreviewStyle
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style.gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style.chrome.opacity(0.16), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(Array(style.windowChromeColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 7, height: 7)
                    }
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(style.chrome.opacity(0.35))
                    .frame(height: 9)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(style.accent.gradient)
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(style.text.opacity(0.9))
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(style.subtleText)
                        .frame(height: 7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if isActive {
                LinearGradient(colors: [style.accent.primary.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity)
            }
        }
    }
}

private struct ThemePreviewStyle {
    let gradient: LinearGradient
    let chrome: Color
    let accent: (primary: Color, gradient: LinearGradient)
    let text: Color
    let subtleText: Color
    let shadow: Color
    let stroke: Color
    let cardBackground: Color
    let contentForeground: Color
    let subtitle: String

    var windowChromeColors: [Color] { [.red.opacity(0.9), .orange.opacity(0.9), .green.opacity(0.85)] }
}

private extension AppTheme {
    var previewStyle: ThemePreviewStyle {
        switch self {
        case .light:
            return ThemePreviewStyle(
                gradient: LinearGradient(
                    colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.93, green: 0.95, blue: 0.99)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                chrome: Color(red: 0.84, green: 0.86, blue: 0.9),
                accent: (
                    primary: Color(red: 0.35, green: 0.46, blue: 0.97),
                    gradient: LinearGradient(colors: [Color(red: 0.35, green: 0.46, blue: 0.97), Color(red: 0.51, green: 0.61, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                ),
                text: Color(red: 0.22, green: 0.26, blue: 0.34),
                subtleText: Color(red: 0.72, green: 0.77, blue: 0.84),
                shadow: Color.black.opacity(0.25),
                stroke: Color(red: 0.82, green: 0.86, blue: 0.93),
                cardBackground: Color(red: 0.98, green: 0.99, blue: 1.0),
                contentForeground: Color.black.opacity(0.85),
                subtitle: "Bright surfaces, subtle glass highlights"
            )
        case .dark:
            return ThemePreviewStyle(
                gradient: LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.13), Color(red: 0.17, green: 0.19, blue: 0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                chrome: Color(red: 0.26, green: 0.29, blue: 0.35),
                accent: (
                    primary: Color(red: 0.66, green: 0.78, blue: 1.0),
                    gradient: LinearGradient(colors: [Color(red: 0.52, green: 0.69, blue: 1.0), Color(red: 0.72, green: 0.83, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                ),
                text: Color(red: 0.86, green: 0.9, blue: 0.97),
                subtleText: Color(red: 0.49, green: 0.53, blue: 0.61),
                shadow: Color.black.opacity(0.6),
                stroke: Color(red: 0.2, green: 0.23, blue: 0.29),
                cardBackground: Color(red: 0.12, green: 0.14, blue: 0.18),
                contentForeground: Color.white.opacity(0.95),
                subtitle: "Deep contrast with midnight chroma"
            )
        case .system:
            return ThemePreviewStyle(
                gradient: LinearGradient(
                    colors: [Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.92, green: 0.94, blue: 0.97)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                chrome: Color(red: 0.5, green: 0.56, blue: 0.64),
                accent: (
                    primary: Color(red: 0.32, green: 0.65, blue: 0.96),
                    gradient: LinearGradient(colors: [Color(red: 0.32, green: 0.65, blue: 0.96), Color(red: 0.46, green: 0.78, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                ),
                text: Color(red: 0.23, green: 0.28, blue: 0.37),
                subtleText: Color(red: 0.62, green: 0.68, blue: 0.76),
                shadow: Color.black.opacity(0.35),
                stroke: Color(red: 0.7, green: 0.76, blue: 0.84),
                cardBackground: Color(red: 0.92, green: 0.94, blue: 0.97),
                contentForeground: Color.black.opacity(0.85),
                subtitle: "Adapts with your macOS appearance"
            )
        }
    }
}

private struct PaletteCard: View {
    let palette: SQLEditorPalette
    let isSelected: Bool
    let action: () -> Void

    private var descriptor: String {
        palette.isDark ? "Optimized for dark backgrounds" : "Optimized for light backgrounds"
    }

    private var badgeBackground: Color {
        palette.isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.07)
    }

    private var badgeForeground: Color {
        palette.isDark ? .white.opacity(0.9) : Color.black.opacity(0.7)
    }

    private var cardShadow: Color {
        palette.isDark ? .black.opacity(0.55) : .black.opacity(0.18)
    }

    private var cardFill: Color {
        palette.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                PalettePreview(palette: palette)
                    .environment(\.colorScheme, palette.isDark ? .dark : .light)
                    .frame(width: 116, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(palette.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(palette.name)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(palette.isDark ? "Dark" : "Light")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeBackground)
                            )

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Selected palette")
                        }
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(palette.showcaseColors.enumerated()), id: \.offset) { _, swatch in
                            Capsule(style: .continuous)
                                .fill(swatch)
                                .frame(width: 26, height: 10)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(palette.isDark ? 0.4 : 0.2), lineWidth: 0.6)
                                )
                        }
                    }

                    Text(descriptor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: cardShadow, radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension SQLEditorPalette {
    var showcaseColors: [Color] {
        [
            tokens.keyword.color,
            tokens.string.color,
            tokens.operatorSymbol.color,
            tokens.identifier.color,
            tokens.comment.color
        ]
    }
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}
