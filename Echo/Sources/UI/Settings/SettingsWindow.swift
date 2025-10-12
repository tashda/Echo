import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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
    @EnvironmentObject private var appState: AppState
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
#if os(macOS)
        .toolbar(removing: .sidebarToggle)
#endif
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
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .background(themeManager.windowBackground)
#if os(macOS)
        .background(
            WindowAppearanceConfigurator(windowBackground: themeManager.windowBackground)
        )
#endif
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
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
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
        .background(themeManager.surfaceBackgroundColor)
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:
            AppearanceSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
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

enum PaletteToneMode: Hashable {
    case light
    case dark
    case both
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var isUpdatingTheme = false
    @State private var isUpdatingPalette = false

    @State private var themePendingDeletion: AppColorTheme?
    @State private var palettePendingDeletion: SQLEditorTokenPalette?

    @State private var themeEditorTone: SQLEditorPalette.Tone = .light
    @State private var themeEditorMode: ThemeEditorMode = .create
    @State private var themeEditorDraft = AppColorTheme.fromPalette(.aurora)

    @State private var paletteEditorTone: SQLEditorPalette.Tone = .light
    @State private var paletteEditorToneMode: PaletteToneMode = .light
    @State private var paletteEditorMode: PaletteEditorMode = .create
    @State private var paletteEditorDraft = SQLEditorTokenPalette(from: SQLEditorPalette.aurora)

    @State private var isThemeEditorPresented = false
    @State private var isPaletteEditorPresented = false

#if os(macOS)
    @StateObject private var fontPickerCoordinator = SystemFontPickerCoordinator()
#endif


    var body: some View {
        Form {
            appearanceModeSection

            if shouldShowSection(for: .light) {
                toneSection(for: .light, title: "Light Appearance")
                queryEditorSection(for: .light, title: "Query Editor (Light)")
            }

            if shouldShowSection(for: .dark) {
                toneSection(for: .dark, title: "Dark Appearance")
                queryEditorSection(for: .dark, title: "Query Editor (Dark)")
            }

            themeCustomizationSection
            resultsGridSection
            editorDisplaySection
            informationSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
        .background(
            SettingsWindowConfigurator(themeManager: themeManager)
                .frame(width: 0, height: 0)
        )
        .alert(
            "Delete Theme?",
            isPresented: Binding(
                get: { themePendingDeletion != nil },
                set: { if !$0 { themePendingDeletion = nil } }
            ),
            presenting: themePendingDeletion
        ) { theme in
            Button("Delete", role: .destructive) {
                deleteTheme(theme)
            }
            Button("Cancel", role: .cancel) {
                themePendingDeletion = nil
            }
        } message: { theme in
            Text("Deleting “\(theme.name)” removes it from the theme list. Windows using it will fall back to the palette default.")
        }
        .alert(
            "Delete Palette?",
            isPresented: Binding(
                get: { palettePendingDeletion != nil },
                set: { if !$0 { palettePendingDeletion = nil } }
            ),
            presenting: palettePendingDeletion
        ) { palette in
            Button("Delete", role: .destructive) {
                deletePalette(palette)
            }
            Button("Cancel", role: .cancel) {
                palettePendingDeletion = nil
            }
        } message: { palette in
            Text("Deleting “\(palette.name)” removes it from the palette list. Editors using it will fall back to the theme’s default palette.")
        }
        .sheet(isPresented: $isThemeEditorPresented) {
            ThemeEditorSheet(
                tone: themeEditorTone,
                draft: $themeEditorDraft,
                mode: themeEditorMode,
                availablePalettes: availablePalettes(for: themeEditorTone),
                isSaving: isUpdatingTheme,
                onCancel: cancelThemeEditing,
                onSave: persistThemeEditorDraft
            )
        }
        .sheet(isPresented: $isPaletteEditorPresented) {
            TokenPaletteEditorSheet(
                tone: $paletteEditorTone,
                toneMode: $paletteEditorToneMode,
                draft: $paletteEditorDraft,
                mode: paletteEditorMode,
                isSaving: isUpdatingPalette,
                onCancel: cancelPaletteEditing,
                onSave: persistPaletteEditorDraft
            )
        }
    }

    private func shouldShowSection(for tone: SQLEditorPalette.Tone) -> Bool {
        switch appModel.globalSettings.appearanceMode {
        case .system:
            return true
        case .light:
            return tone == .light
        case .dark:
            return tone == .dark
        }
    }

    private var appearanceModeSection: some View {
        Section("Appearance Mode") {
            Picker("Appearance Mode", selection: appearanceModeBinding) {
                Text("System").tag(AppearanceMode.system)
                Text("Light").tag(AppearanceMode.light)
                Text("Dark").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func toneSection(for tone: SQLEditorPalette.Tone, title: String) -> some View {
        Section(title) {
            let themes = availableThemes(for: tone)
            let selectedThemeID = appModel.globalSettings.activeThemeID(for: tone)
            ThemeAppearanceSection(
                tone: tone,
                themes: themes,
                selectedThemeID: selectedThemeID,
                isUpdatingTheme: isUpdatingTheme,
                paletteResolver: { palette(for: $0) },
                onSelectTheme: { theme in
                    selectTheme(theme.id, tone: tone, defaultPaletteID: theme.defaultPaletteID)
                },
                onCreateTheme: { startCreatingTheme(tone: tone) },
                onEditTheme: { theme in startEditingTheme(theme, tone: tone) },
                onDuplicateTheme: { theme in startDuplicatingTheme(theme, tone: tone) },
                onDeleteTheme: { theme in themePendingDeletion = theme }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Themes control window chrome, toolbars, and workspace surfaces.")
                Text("Palettes customise SQL editor token colours.")
                if tone == .dark {
                    Text("Light and dark settings are stored independently so System mode can switch cleanly.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func queryEditorSection(for tone: SQLEditorPalette.Tone, title: String) -> some View {
        let themes = availableThemes(for: tone)
        let selectedThemeID = appModel.globalSettings.activeThemeID(for: tone)
        let theme = appModel.globalSettings.theme(withID: selectedThemeID, tone: tone)
            ?? themes.first
            ?? themeManager.theme(for: tone)
        let palettes = availablePalettes(for: tone)
        let selectedPaletteID = appModel.globalSettings.defaultPaletteID(for: tone)

        return Section(title) {
            QueryEditorSection(
                tone: tone,
                theme: theme,
                palettes: palettes,
                selectedPaletteID: selectedPaletteID,
                isUpdatingPalette: isUpdatingPalette,
                selectedFontName: editorFontFamilyBinding.wrappedValue,
                fontOptions: editorFontOptions,
                fontDisplayNameProvider: fontDisplayName(for:),
                onSelectPalette: { palette in selectPalette(palette, tone: tone) },
                onCreatePalette: { startCreatingPalette(tone: tone) },
                onEditPalette: { palette in startEditingPalette(palette, tone: tone) },
                onDuplicatePalette: { palette in startDuplicatingPalette(palette, tone: tone) },
                onDeletePalette: { palette in palettePendingDeletion = palette },
                onSelectFont: { editorFontFamilyBinding.wrappedValue = $0 },
                onRequestCustomFont: { presentFontPicker() }
            )
        }
    }

    private var themeCustomizationSection: some View {
        Section("Theme Customizations") {
            Toggle("Use connected server color as accent", isOn: useServerAccentBinding)
                .toggleStyle(.switch)

            Toggle("Match workspace tabs to editor theme", isOn: themeTabsBinding)
                .toggleStyle(.switch)

            Text("Apply connection colors outside the editor and sync workspace tabs with the active theme.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var resultsGridSection: some View {
        Section("Results Grid") {
            resultsGridPreview

            Toggle("Use application theme", isOn: themeResultsGridBinding)
                .toggleStyle(.switch)

            Toggle("Show alternate row shading", isOn: alternateRowShadingBinding)
                .toggleStyle(.switch)

            Text("Preview updates as you toggle the options above.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var resultsGridPreview: some View {
        let theme = themeManager.activeTheme
        return ResultsGridPreview(
            tone: theme.tone,
            theme: theme,
            useThemedAppearance: themeResultsGridBinding.wrappedValue,
            alternateRows: alternateRowShadingBinding.wrappedValue
        )
        .frame(maxWidth: .infinity)
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

    private func selectTheme(_ themeID: AppColorTheme.ID?, tone: SQLEditorPalette.Tone, defaultPaletteID: String? = nil) {
        guard !isUpdatingTheme else { return }
        if appModel.globalSettings.activeThemeID(for: tone) == themeID { return }
        isUpdatingTheme = true
        Task { @MainActor in
            await appModel.setActiveTheme(themeID, for: tone)
            if let themeID,
               let theme = appModel.globalSettings.theme(withID: themeID, tone: tone) {
                let targetPaletteID = defaultPaletteID ?? theme.defaultPaletteID
                if availablePalettes(for: tone).contains(where: { $0.id == targetPaletteID }) &&
                    appModel.globalSettings.defaultPaletteID(for: tone) != targetPaletteID {
                    await appModel.setDefaultEditorPalette(to: targetPaletteID, for: tone)
                }
            }
            isUpdatingTheme = false
        }
    }

    private func selectPalette(_ palette: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone) {
        guard !isUpdatingPalette else { return }
        guard palette.tone == tone else { return }
        if appModel.globalSettings.defaultPaletteID(for: tone) == palette.id { return }
        isUpdatingPalette = true
        Task { @MainActor in
            await appModel.setDefaultEditorPalette(to: palette.id, for: tone)
            isUpdatingPalette = false
        }
    }

    private func startCreatingTheme(tone: SQLEditorPalette.Tone) {
        themeEditorTone = tone
        themeEditorMode = .create
        var draft = baseThemeDraft(for: tone)
        draft.id = "custom-theme-\(UUID().uuidString)"
        draft.name = tone == .dark ? "New Dark Theme" : "New Light Theme"
        draft.isCustom = true
        draft.tone = tone
        if let palette = appModel.globalSettings.defaultPalette(for: tone) {
            draft.defaultPaletteID = palette.id
        }
        themeEditorDraft = draft
        isThemeEditorPresented = true
    }

    private func startEditingTheme(_ theme: AppColorTheme, tone: SQLEditorPalette.Tone) {
        themeEditorTone = tone
        themeEditorMode = .edit
        var draft = theme
        draft.tone = tone
        draft.isCustom = true
        themeEditorDraft = draft
        isThemeEditorPresented = true
    }

    private func startDuplicatingTheme(_ theme: AppColorTheme, tone: SQLEditorPalette.Tone) {
        themeEditorTone = tone
        themeEditorMode = .create
        var draft = theme
        draft.id = "custom-theme-\(UUID().uuidString)"
        draft.name = copyName(from: theme.name)
        draft.isCustom = true
        draft.tone = tone
        themeEditorDraft = draft
        isThemeEditorPresented = true
    }

    private func cancelThemeEditing() {
        isThemeEditorPresented = false
    }

    private func persistThemeEditorDraft() {
        guard !isUpdatingTheme else { return }
        isUpdatingTheme = true
        var draft = themeEditorDraft
        draft.tone = themeEditorTone
        draft.isCustom = true
        draft.name = sanitizedName(draft.name, fallback: themeEditorTone == .dark ? "Custom Dark Theme" : "Custom Light Theme")
        if draft.swatchColors.isEmpty {
            draft.swatchColors = defaultSwatches(for: draft)
        }
        let shouldActivate = themeEditorMode == .create
        Task { @MainActor in
            await appModel.upsertCustomTheme(draft)
            if shouldActivate {
                await appModel.setActiveTheme(draft.id, for: themeEditorTone)
                if availablePalettes(for: themeEditorTone).contains(where: { $0.id == draft.defaultPaletteID }) {
                    await appModel.setDefaultEditorPalette(to: draft.defaultPaletteID, for: themeEditorTone)
                }
            }
            isUpdatingTheme = false
            isThemeEditorPresented = false
        }
    }

    private func startCreatingPalette(tone: SQLEditorPalette.Tone) {
        paletteEditorTone = tone
        paletteEditorToneMode = tone == .dark ? .dark : .light
        paletteEditorMode = .create
        let base = appModel.globalSettings.defaultPalette(for: tone)
            ?? SQLEditorTokenPalette.builtIn.first(where: { $0.tone == tone })
            ?? SQLEditorTokenPalette(from: tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
        var draft = base.asCustomCopy(named: tone == .dark ? "New Dark Palette" : "New Light Palette")
        draft.tone = tone
        paletteEditorDraft = draft
        isPaletteEditorPresented = true
    }

    private func startEditingPalette(_ palette: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone) {
        paletteEditorTone = tone
        paletteEditorToneMode = tone == .dark ? .dark : .light
        paletteEditorMode = .edit
        var draft = palette
        draft.tone = tone
        draft.kind = .custom
        paletteEditorDraft = draft
        isPaletteEditorPresented = true
    }

    private func startDuplicatingPalette(_ palette: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone) {
        paletteEditorTone = tone
        paletteEditorToneMode = tone == .dark ? .dark : .light
        paletteEditorMode = .create
        var draft = palette.asCustomCopy(named: copyName(from: palette.name))
        draft.tone = tone
        paletteEditorDraft = draft
        isPaletteEditorPresented = true
    }

    private func cancelPaletteEditing() {
        isPaletteEditorPresented = false
    }

    private func persistPaletteEditorDraft() {
        guard !isUpdatingPalette else { return }
        isUpdatingPalette = true
        let toneMode = paletteEditorToneMode
        let mode = paletteEditorMode
        let baseDraft = paletteEditorDraft
        let shouldSelect = mode == .create

        Task { @MainActor in
            defer {
                isUpdatingPalette = false
                isPaletteEditorPresented = false
            }

            @MainActor
            func save(_ draft: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone, select: Bool) async {
                var draft = draft
                if mode == .create && !draft.id.hasPrefix("custom-") {
                    draft.id = "custom-\(UUID().uuidString)"
                }
                await appModel.upsertCustomPalette(draft)
                if select || appModel.globalSettings.defaultPaletteID(for: tone) == draft.id {
                    await appModel.setDefaultEditorPalette(to: draft.id, for: tone)
                }
            }

            switch toneMode {
            case .light, .dark:
                let tone = toneMode == .dark ? SQLEditorPalette.Tone.dark : .light
                let draft = makePaletteDraft(from: baseDraft, tone: tone, toneMode: toneMode)
                await save(draft, tone: tone, select: shouldSelect)
                paletteEditorTone = tone
            case .both:
                let lightDraft = makePaletteDraft(from: baseDraft, tone: .light, toneMode: toneMode)
                let darkDraft = makePaletteDraft(from: baseDraft, tone: .dark, toneMode: toneMode)
                await save(lightDraft, tone: .light, select: shouldSelect)
                await save(darkDraft, tone: .dark, select: shouldSelect)
                paletteEditorTone = .light
            }
        }
    }

    private func deleteTheme(_ theme: AppColorTheme) {
        guard !isUpdatingTheme else { return }
        isUpdatingTheme = true
        Task { @MainActor in
            await appModel.deleteCustomTheme(withID: theme.id)
            themePendingDeletion = nil
            isUpdatingTheme = false
        }
    }

    private func deletePalette(_ palette: SQLEditorTokenPalette) {
        guard !isUpdatingPalette else { return }
        isUpdatingPalette = true
        Task { @MainActor in
            await appModel.deleteCustomPalette(withID: palette.id)
            palettePendingDeletion = nil
            isUpdatingPalette = false
        }
    }

    private func baseThemeDraft(for tone: SQLEditorPalette.Tone) -> AppColorTheme {
        if let activeID = appModel.globalSettings.activeThemeID(for: tone),
           let theme = appModel.globalSettings.theme(withID: activeID, tone: tone) {
            return theme
        }
        if let matched = appModel.globalSettings.themeMatchingCurrentPalette(for: tone) {
            return matched
        }
        return themeManager.theme(for: tone)
    }

    private func defaultSwatches(for theme: AppColorTheme) -> [ColorRepresentable] {
        if let palette = palette(for: theme.defaultPaletteID) {
            return palette.showcaseColors.map { ColorRepresentable(color: $0) }
        }
        return theme.swatchColors
    }

    private func copyName(from base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled Copy" }
        if trimmed.lowercased().contains("copy") { return trimmed }
        return "\(trimmed) Copy"
    }

    private func sanitizedName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func makePaletteDraft(from base: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone, toneMode: PaletteToneMode) -> SQLEditorTokenPalette {
        var draft = base
        draft.tone = tone
        draft.kind = .custom

        let fallback = tone == .dark ? "Custom Dark Palette" : "Custom Light Palette"
        var name = sanitizedName(draft.name, fallback: fallback)

        if toneMode == .both {
            let keyword = tone == .dark ? "dark" : "light"
            if !name.lowercased().contains(keyword) {
                name += tone == .dark ? " (Dark)" : " (Light)"
            }
        }

        draft.name = name
        return draft
    }

    private func availableThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        appModel.globalSettings.availableThemes(for: tone)
    }

    private func availablePalettes(for tone: SQLEditorPalette.Tone) -> [SQLEditorTokenPalette] {
        appModel.globalSettings.availablePalettes.filter { $0.tone == tone }
    }

    private func palette(for id: String?) -> SQLEditorTokenPalette? {
        guard let id else { return nil }
        return appModel.globalSettings.palette(withID: id)
    }

    private var editorFontOptions: [EditorFontOption] {
        [
            EditorFontOption(id: "FiraCode-Regular", postScriptName: "FiraCode-Regular", displayName: "Fira Code"),
            EditorFontOption(id: "IBMPlexMono-Regular", postScriptName: "IBMPlexMono-Regular", displayName: "IBM Plex Mono"),
            EditorFontOption(id: "SplineSansMono-Regular", postScriptName: "SplineSansMono-Regular", displayName: "Spline Sans Mono"),
            EditorFontOption(id: "RecursiveMonoLinear-Regular", postScriptName: "RecursiveMonoLinear-Regular", displayName: "Recursive Mono"),
            EditorFontOption(id: "JetBrainsMono-Regular", postScriptName: "JetBrainsMono-Regular", displayName: "JetBrains Mono")
        ]
    }

    private var editorFontFamilyBinding: Binding<String> {
        Binding(
            get: { appModel.globalSettings.defaultEditorFontFamily },
            set: { newValue in
                guard appModel.globalSettings.defaultEditorFontFamily != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.defaultEditorFontFamily = newValue } }
            }
        )
    }

    private func fontDisplayName(for fontName: String) -> String {
        if let option = editorFontOptions.first(where: { $0.postScriptName == fontName }) {
            return option.displayName
        }
#if os(macOS)
        if let font = NSFont(name: fontName, size: 12) {
            return font.displayName ?? fontName
        }
#elseif canImport(UIKit)
        if let font = UIFont(name: fontName, size: 12) {
            return font.familyName
        }
#endif
        return fontName
    }

    private func presentFontPicker() {
#if os(macOS)
        fontPickerCoordinator.present(currentFontName: editorFontFamilyBinding.wrappedValue) { fontName in
            editorFontFamilyBinding.wrappedValue = fontName
        }
#endif
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { appModel.globalSettings.appearanceMode },
            set: { newValue in
                guard appModel.globalSettings.appearanceMode != newValue else { return }
                themeManager.applyAppearanceMode(newValue)
                Task {
                    await appModel.updateGlobalEditorDisplay { settings in
                        settings.appearanceMode = newValue
                    }
                }
            }
        )
    }

    private var useServerAccentBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.useServerColorAsAccent },
            set: { newValue in
                guard appModel.globalSettings.useServerColorAsAccent != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.useServerColorAsAccent = newValue } }
            }
        )
    }

    private var themeTabsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.themeTabs },
            set: { newValue in
                guard appModel.globalSettings.themeTabs != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.themeTabs = newValue } }
            }
        )
    }

    private var themeResultsGridBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.themeResultsGrid },
            set: { newValue in
                guard appModel.globalSettings.themeResultsGrid != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.themeResultsGrid = newValue } }
            }
        )
    }

    private var alternateRowShadingBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.resultsAlternateRowShading },
            set: { newValue in
                guard appModel.globalSettings.resultsAlternateRowShading != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.resultsAlternateRowShading = newValue } }
            }
        )
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

    private func lineSpacingLabel(for value: Double) -> String {
        let clamped = min(max(value, 1.0), 2.0)
        return String(format: "%.2fx", clamped)
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
}

private enum ThemeEditorMode {
    case create
    case edit
}

private enum PaletteEditorMode {
    case create
    case edit
}


private struct ThemeAppearanceSection: View {
    let tone: SQLEditorPalette.Tone
    let themes: [AppColorTheme]
    let selectedThemeID: String?
    let isUpdatingTheme: Bool
    let paletteResolver: (String?) -> SQLEditorTokenPalette?
    let onSelectTheme: (AppColorTheme) -> Void
    let onCreateTheme: () -> Void
    let onEditTheme: (AppColorTheme) -> Void
    let onDuplicateTheme: (AppColorTheme) -> Void
    let onDeleteTheme: (AppColorTheme) -> Void

    @State private var hoveredThemeID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptivePreviewGrid(
                hero: heroPreview,
                secondary: paletteSummary,
                minimumHeight: previewTileHeight + 60
            )

            Text("Themes")
                .font(.headline)

            LazyVGrid(columns: chipColumns, spacing: 12) {
                ForEach(themes) { theme in
                    let palette = resolvedPalette(for: theme)
                    ThemeChip(
                        title: theme.name,
                        subtitle: palette.name,
                        swatchColors: swatches(for: theme, palette: palette),
                        isSelected: selectedThemeID == theme.id,
                        isBusy: isUpdatingTheme && selectedThemeID == theme.id,
                        isDisabled: isUpdatingTheme,
                        badge: themeBadge(for: theme, palette: palette),
                        onTap: { onSelectTheme(theme) },
                        onHoverChanged: { hovering in hoveredThemeID = hovering ? theme.id : nil },
                        showsContextMenu: true
                    ) {
                        if theme.isCustom {
                            Button("Edit Theme…") { onEditTheme(theme) }
                            Button("Duplicate…") { onDuplicateTheme(theme) }
                            Button("Delete", role: .destructive) { onDeleteTheme(theme) }
                        } else {
                            Button("Duplicate…") { onDuplicateTheme(theme) }
                        }
                    }
                    .disabled(isUpdatingTheme)
                }
            }

            HStack {
                Button("New Theme…", action: onCreateTheme)
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdatingTheme)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.16), value: hoveredThemeID)
    }

    private var heroPreview: some View {
        let theme = displayedTheme
        let palette = resolvedPalette(for: theme)
        return PreviewTile(
            title: theme.name,
            subtitle: nil,
            background: themeHeroGradient(for: theme),
            shadowColor: (theme.accent?.color ?? palette.tokens.keyword.swiftColor).opacity(theme.tone == .dark ? 0.26 : 0.18)
        ) {
            ThemePreview(theme: theme, palette: palette, layout: .regular)
                .scaleEffect(1.02)
        }
    }

    private var paletteSummary: some View {
        let theme = displayedTheme
        let palette = resolvedPalette(for: theme)
        return PreviewTile(
            title: palette.name,
            subtitle: "Default Palette",
            background: paletteHeroGradient(for: theme, palette: palette),
            shadowColor: palette.tokens.keyword.swiftColor.opacity(theme.tone == .dark ? 0.22 : 0.14)
        ) {
            QueryEditorPreview(theme: theme, palette: palette, fontName: "JetBrainsMono-Regular")
                .scaleEffect(0.94)
        }
    }

    private var chipColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 152, maximum: 220), spacing: 12)]
    }

    private func themeHeroGradient(for theme: AppColorTheme) -> LinearGradient {
        let base = theme.windowBackground.color
        let secondary = theme.surfaceBackground.color
        let accent = theme.accent?.color ?? theme.surfaceForeground.color
        return LinearGradient(
            colors: [
                base.lerp(to: accent, fraction: theme.tone == .dark ? 0.08 : 0.05),
                secondary.lerp(to: Color.white, fraction: theme.tone == .dark ? 0.02 : 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func paletteHeroGradient(for theme: AppColorTheme, palette: SQLEditorTokenPalette) -> LinearGradient {
        let base = theme.editorBackground.color
        let accent = palette.tokens.keyword.swiftColor
        return LinearGradient(
            colors: [
                base,
                base.lerp(to: accent, fraction: theme.tone == .dark ? 0.12 : 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var displayedTheme: AppColorTheme {
        if let hovered = hoveredThemeID,
           let match = themes.first(where: { $0.id == hovered }) {
            return match
        }
        if let selected = selectedThemeID,
           let match = themes.first(where: { $0.id == selected }) {
            return match
        }
        return themes.first ?? AppColorTheme.fromPalette(tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    private func resolvedPalette(for theme: AppColorTheme) -> SQLEditorTokenPalette {
        if let palette = paletteResolver(theme.defaultPaletteID) {
            return palette
        }
        if let palette = SQLEditorTokenPalette.palette(withID: theme.defaultPaletteID) {
            return palette
        }
        return SQLEditorTokenPalette(from: theme.tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    private func swatches(for theme: AppColorTheme, palette: SQLEditorTokenPalette) -> [Color] {
        let swatches = theme.swatchColors.map { $0.color }
        if !swatches.isEmpty {
            return Array(swatches.prefix(6))
        }
        return Array(palette.showcaseColors.prefix(6))
    }

    private func themeBadge(for theme: AppColorTheme, palette: SQLEditorTokenPalette) -> ChipBadge? {
        guard theme.isCustom else { return nil }
        let accent = theme.accent?.color ?? palette.tokens.keyword.swiftColor
        return ChipBadge(label: "Custom", foreground: accent, background: accent.opacity(0.16))
    }
}

private struct QueryEditorSection: View {
    let tone: SQLEditorPalette.Tone
    let theme: AppColorTheme
    let palettes: [SQLEditorTokenPalette]
    let selectedPaletteID: String
    let isUpdatingPalette: Bool
    let selectedFontName: String
    let fontOptions: [EditorFontOption]
    let fontDisplayNameProvider: (String) -> String
    let onSelectPalette: (SQLEditorTokenPalette) -> Void
    let onCreatePalette: () -> Void
    let onEditPalette: (SQLEditorTokenPalette) -> Void
    let onDuplicatePalette: (SQLEditorTokenPalette) -> Void
    let onDeletePalette: (SQLEditorTokenPalette) -> Void
    let onSelectFont: (String) -> Void
    let onRequestCustomFont: () -> Void

    @State private var hoveredPaletteID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            queryPreview

            Text("Palettes")
                .font(.headline)

            if palettes.isEmpty {
                Text("No palettes available for this tone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: chipColumns, spacing: 12) {
                    ForEach(palettes, id: \.id) { palette in
                        PaletteChip(
                            palette: palette,
                            isSelected: selectedPaletteID == palette.id,
                            isBusy: isUpdatingPalette && selectedPaletteID == palette.id,
                            isDisabled: isUpdatingPalette,
                            badge: paletteBadge(for: palette),
                            onTap: { onSelectPalette(palette) },
                            onHoverChanged: { hovering in hoveredPaletteID = hovering ? palette.id : nil },
                            showsContextMenu: true
                        ) {
                            if palette.kind == .custom {
                                Button("Edit Palette…") { onEditPalette(palette) }
                                Button("Duplicate…") { onDuplicatePalette(palette) }
                                Button("Delete", role: .destructive) { onDeletePalette(palette) }
                            } else {
                                Button("Duplicate…") { onDuplicatePalette(palette) }
                            }
                        }
                        .disabled(isUpdatingPalette)
                    }
                }
            }

            HStack {
                Button("New Palette…", action: onCreatePalette)
                    .buttonStyle(.bordered)
                    .disabled(isUpdatingPalette)
                Spacer()
            }

            Divider()

            fontPicker
        }
        .animation(.easeInOut(duration: 0.16), value: hoveredPaletteID)
    }

    private var chipColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 152, maximum: 220), spacing: 12)]
    }

    private var displayedPalette: SQLEditorTokenPalette {
        if let hovered = hoveredPaletteID,
           let palette = palettes.first(where: { $0.id == hovered }) {
            return palette
        }
        return palettes.first(where: { $0.id == selectedPaletteID })
            ?? palettes.first
            ?? SQLEditorTokenPalette(from: tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    private var manualSelectionActive: Bool {
        selectedPaletteID != theme.defaultPaletteID
    }

    private var queryPreview: some View {
        let palette = displayedPalette
        return VStack(alignment: .leading, spacing: 8) {
            Text(palette.name)
                .font(.headline)
            QueryEditorPreview(theme: theme, palette: palette, fontName: selectedFontName)
                .overlay(alignment: .topTrailing) {
                    if manualSelectionActive && hoveredPaletteID == nil {
                        TagBadge(
                            label: "Manual",
                            foreground: Color.accentColor,
                            background: Color.accentColor.opacity(0.18)
                        )
                        .padding(12)
                    }
                }
            Text(fontDisplayNameProvider(selectedFontName))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fontPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editor Font")
                .font(.headline)

            let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(fontOptions) { option in
                    FontChip(
                        title: option.displayName,
                        sampleFontName: option.postScriptName,
                        isSelected: selectedFontName == option.postScriptName,
                        onSelect: { onSelectFont(option.postScriptName) }
                    )
                }

                if !fontOptions.contains(where: { $0.postScriptName == selectedFontName }) {
                    FontChip(
                        title: fontDisplayNameProvider(selectedFontName),
                        sampleFontName: selectedFontName,
                        isSelected: true,
                        onSelect: { onSelectFont(selectedFontName) },
                        isCustom: true
                    )
                }
            }

            Button("Choose from System…", action: onRequestCustomFont)
                .buttonStyle(.bordered)
        }
    }

    private func paletteBadge(for palette: SQLEditorTokenPalette) -> ChipBadge? {
        guard palette.kind == .custom else { return nil }
        let accent = palette.tokens.keyword.swiftColor
        return ChipBadge(label: "Custom", foreground: accent, background: accent.opacity(0.16))
    }
}

private struct ThemeChip<ContextMenuContent: View>: View {
    let title: String
    let subtitle: String?
    let swatchColors: [Color]
    let isSelected: Bool
    let isBusy: Bool
    let isDisabled: Bool
    let badge: ChipBadge?
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    let showsContextMenu: Bool
    @ViewBuilder var contextMenu: () -> ContextMenuContent

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                SwatchStripView(colors: swatchPreview)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .frame(minWidth: 148, maxWidth: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if let badge {
                    TagBadge(label: badge.label, foreground: badge.foreground, background: badge.background)
                        .padding(8)
                }
            }
            .overlay {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovering = hovering
            onHoverChanged(hovering)
        }
        .optionalContextMenu(isEnabled: showsContextMenu, content: contextMenu)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var swatchPreview: [Color] {
        let preview = swatchColors
        if preview.isEmpty {
            return [Color.primary.opacity(0.55)]
        }
        return Array(preview.prefix(6))
    }
}

private struct PaletteChip<ContextMenuContent: View>: View {
    let palette: SQLEditorTokenPalette
    let isSelected: Bool
    let isBusy: Bool
    let isDisabled: Bool
    let badge: ChipBadge?
    let onTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    let showsContextMenu: Bool
    @ViewBuilder var contextMenu: () -> ContextMenuContent

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                SwatchStripView(colors: Array(palette.showcaseColors.prefix(6)))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(palette.tone == .dark ? "Dark palette" : "Light palette")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(minWidth: 148, maxWidth: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if let badge {
                    TagBadge(label: badge.label, foreground: badge.foreground, background: badge.background)
                        .padding(8)
                }
            }
            .overlay {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: isHovering)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovering = hovering
            onHoverChanged(hovering)
        }
        .optionalContextMenu(isEnabled: showsContextMenu, content: contextMenu)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemePreview: View {
    enum Layout {
        case regular
        case compact

        var size: CGSize {
            switch self {
            case .regular:
                return CGSize(width: 136, height: 72)
            case .compact:
                return CGSize(width: 104, height: 52)
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular: return 8
            case .compact: return 5
            }
        }

        var sidebarWidth: CGFloat {
            switch self {
            case .regular: return 44
            case .compact: return 30
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .regular: return 10
            case .compact: return 7
            }
        }
    }

    let theme: AppColorTheme?
    let palette: SQLEditorTokenPalette?
    var layout: Layout = .regular
#if DEBUG
    @State private var debugLoggedSize: CGSize = .zero
#endif

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(windowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                        .blendMode(.overlay)
                )

            VStack(spacing: layout == .regular ? 6 : 5) {
                chromeBar

                HStack(spacing: layout == .regular ? 6 : 4) {
                    sidebarPreview
                    EditorTokenPreview(
                        background: editorBackgroundColor,
                        gutter: editorGutterBackgroundColor,
                        gutterAccent: editorGutterAccentColor,
                        gutterForeground: editorGutterForegroundColor,
                        selection: editorSelectionColor,
                        currentLine: editorCurrentLineColor,
                        tokenColors: resolvedTokens,
                        isDark: isDark
                    )
                    .frame(height: layout == .regular ? 56 : 44)
                }

                if !swatchColors.isEmpty {
                    SwatchStripView(colors: swatchColors)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(layout.padding)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
#if DEBUG
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { reportSizeIfNeeded(proxy.size) }
                    .onChange(of: proxy.size) { newSize in reportSizeIfNeeded(newSize) }
            }
        )
#endif
    }

    private var isDark: Bool {
        if let tone = theme?.tone {
            return tone == .dark
        }
        return palette?.tone == .dark
    }

    private var windowFill: LinearGradient {
        let top = windowColor.opacity(isDark ? 0.9 : 1.0)
        let bottom = windowColor.opacity(isDark ? 0.8 : 0.92)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var chromeBar: some View {
        HStack(spacing: layout == .regular ? 4 : 3) {
            trafficLight(Color(red: 0.99, green: 0.31, blue: 0.29))
            trafficLight(Color(red: 0.99, green: 0.76, blue: 0.2))
            trafficLight(Color(red: 0.3, green: 0.85, blue: 0.39))

            Spacer()

            Capsule(style: .continuous)
                .fill(accentColor.opacity(isDark ? 0.6 : 0.78))
                .frame(width: layout == .regular ? 32 : 26, height: layout == .regular ? 6 : 5)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isDark ? 0.08 : 0.25), lineWidth: 1)
                )
        }
        .padding(.horizontal, layout == .regular ? 6 : 4)
        .padding(.vertical, layout == .regular ? 4 : 2)
        .background(
            RoundedRectangle(cornerRadius: layout == .regular ? 8 : 6, style: .continuous)
                .fill(surfaceColor.opacity(isDark ? 0.45 : 0.6))
        )
    }

    private func trafficLight(_ color: Color) -> some View {
        Circle()
            .fill(color.opacity(isDark ? 0.9 : 0.85))
            .frame(width: layout == .regular ? 8 : 6, height: layout == .regular ? 8 : 6)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(isDark ? 0.08 : 0.25), lineWidth: 0.8)
            )
    }

    private var sidebarPreview: some View {
        VStack(alignment: .leading, spacing: layout == .regular ? 4 : 3) {
            Capsule(style: .continuous)
                .fill(accentColor.opacity(isDark ? 0.56 : 0.46))
                .frame(width: layout.sidebarWidth * 0.62, height: layout == .regular ? 6 : 4.5)
            Capsule(style: .continuous)
                .fill(surfaceForeground.opacity(isDark ? 0.56 : 0.32))
                .frame(width: layout.sidebarWidth * 0.55, height: layout == .regular ? 4.8 : 4)
            Capsule(style: .continuous)
                .fill(surfaceForeground.opacity(isDark ? 0.5 : 0.28))
                .frame(width: layout.sidebarWidth * 0.7, height: layout == .regular ? 4.8 : 4)
            Capsule(style: .continuous)
                .fill(surfaceForeground.opacity(isDark ? 0.4 : 0.22))
                .frame(width: layout.sidebarWidth * 0.48, height: layout == .regular ? 4.6 : 3.8)
        }
        .padding(.vertical, layout == .regular ? 8 : 6)
        .padding(.horizontal, layout == .regular ? 6 : 5)
        .frame(width: layout.sidebarWidth)
        .background(
            RoundedRectangle(cornerRadius: layout == .regular ? 11 : 9, style: .continuous)
                .fill(surfaceColor.opacity(isDark ? 0.5 : 0.38))
        )
    }

    private var surfaceForeground: Color {
        theme?.surfaceForeground.color ?? basePalette.text.color
    }

    private var editorBackgroundColor: Color {
        theme?.editorBackground.color
            ?? basePalette.background.color
    }

    private var editorGutterBackgroundColor: Color {
        theme?.editorGutterBackground.color
            ?? basePalette.gutterBackground.color
    }

    private var editorGutterAccentColor: Color {
        theme?.accent?.color
            ?? basePalette.gutterAccent.color
    }

    private var editorGutterForegroundColor: Color {
        theme?.editorGutterForeground.color
            ?? basePalette.gutterText.color
    }

    private var editorSelectionColor: Color {
        theme?.editorSelection.color
            ?? basePalette.selection.color
    }

    private var editorCurrentLineColor: Color {
        theme?.editorCurrentLine.color
            ?? basePalette.currentLine.color
    }

    private var windowColor: Color {
        theme?.windowBackground.color ?? basePalette.background.color
    }

    private var surfaceColor: Color {
        theme?.surfaceBackground.color ?? basePalette.background.color
    }

    private var accentColor: Color {
        theme?.accent?.color ?? basePalette.tokens.keyword.swiftColor
    }

    private var basePalette: SQLEditorPalette {
        if let themePaletteID = theme?.defaultPaletteID,
           let resolved = SQLEditorPalette.palette(withID: themePaletteID) {
            return resolved
        }
        if let palette, let resolved = SQLEditorPalette.palette(withID: palette.id) {
            return resolved
        }
        return theme?.tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
    }

    private var resolvedTokens: SQLEditorPalette.TokenColors {
        if let palette {
            return palette.tokens
        }
        return basePalette.tokens
    }

    private var swatchColors: [Color] {
        if let theme, !theme.swatchColors.isEmpty {
            return theme.swatchColors.map { $0.color }
        }
        if let palette {
            return Array(palette.showcaseColors.prefix(5))
        }
        return []
    }

#if DEBUG
    private func reportSizeIfNeeded(_ size: CGSize) {
        guard debugLoggedSize != size else { return }
        debugLoggedSize = size
        print("ThemePreview layout \(layout) size: \(size)")
    }
#endif
}

private struct ResultsGridPreview: View {
    let tone: SQLEditorPalette.Tone
    let theme: AppColorTheme
    let useThemedAppearance: Bool
    let alternateRows: Bool
    private let columns: [PreviewColumn] = PreviewColumn.sampleColumns
    private let sampleRows: [[String?]] = PreviewColumn.sampleRows

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            tablePreview
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var tablePreview: some View {
#if os(macOS)
        let neutralBackground = Color(nsColor: .textBackgroundColor)
        let neutralText = Color(nsColor: .labelColor)
#else
        let neutralBackground = Color(uiColor: .systemBackground)
        let neutralText = Color(uiColor: .label)
#endif
        let baseBackground = useThemedAppearance ? theme.windowBackground.color : neutralBackground
        let textColor = useThemedAppearance ? theme.surfaceForeground.color : neutralText
        let accent = theme.accent?.color ?? textColor
        let evenRow = baseBackground
        let oddRow = alternateRows ? baseBackground.lerp(to: accent, fraction: 0.04) : baseBackground

        return VStack(spacing: 0) {
            headerRow(textColor: textColor)
            ForEach(sampleRows.indices, id: \.self) { index in
                row(index: index,
                    color: index.isMultiple(of: 2) ? evenRow : oddRow,
                    textColor: textColor)
            }
        }
        .background(baseBackground)
    }

    private func headerRow(textColor: Color) -> some View {
        return HStack {
            ForEach(columns) { column in
                Text(column.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((theme.accent?.color ?? textColor).opacity(0.12))
        .foregroundStyle(textColor)
    }

    private func row(index: Int, color: Color, textColor: Color) -> some View {
        let values = sampleRows[index]
        return HStack {
            ForEach(columns) { column in
                Text(values[column.index] ?? "—")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color)
        .foregroundStyle(textColor.opacity(0.9))
    }

    private struct PreviewColumn: Identifiable {
        let id = UUID()
        let index: Int
        let title: String

        static let sampleColumns: [PreviewColumn] = [
            PreviewColumn(index: 0, title: "ID"),
            PreviewColumn(index: 1, title: "Status"),
            PreviewColumn(index: 2, title: "Created"),
            PreviewColumn(index: 3, title: "Owner")
        ]

        static let sampleRows: [[String?]] = [
            ["1", "Active", "2024-10-30", "primary"],
            ["2", "Pending", "2024-10-18", "review"],
            ["3", "Active", "2024-09-27", "ops"],
            ["4", nil, "2024-07-12", "archive"]
        ]
    }
}

private let previewTileHeight: CGFloat = 184

private struct AdaptivePreviewGrid<Hero: View, Secondary: View>: View {
    let hero: Hero
    let secondary: Secondary
    var minimumHeight: CGFloat

    init(hero: Hero, secondary: Secondary, minimumHeight: CGFloat = 340) {
        self.hero = hero
        self.secondary = secondary
        self.minimumHeight = minimumHeight
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 24
            let availableWidth = max(proxy.size.width - spacing, 0)
            let cardWidth = availableWidth / 2

            HStack(alignment: .top, spacing: spacing) {
                hero
                    .frame(width: cardWidth, alignment: .top)
                secondary
                    .frame(width: cardWidth, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: minimumHeight)
    }
}
#if os(macOS)
private struct WindowAppearanceConfigurator: NSViewRepresentable {
    let windowBackground: Color

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(for: nsView)
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(for: nsView)
        }
    }

    private func configure(for nsView: NSView) {
        guard let window = nsView.window else { return }
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
    }
}
#endif

private struct PreviewTile<Content: View>: View {
    let title: String
    let subtitle: String?
    let background: LinearGradient
    let shadowColor: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            .blendMode(.overlay)
                    )

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(26)
            }
            .frame(height: previewTileHeight)
            .shadow(color: shadowColor, radius: 24, x: 0, y: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct QueryEditorPreview: View {
    let theme: AppColorTheme
    let palette: SQLEditorTokenPalette
    let fontName: String

    var body: some View {
        PaletteSnippetPreview(
            background: theme.editorBackground.color,
            gutterBackground: theme.editorGutterBackground.color,
            gutterForeground: theme.editorGutterForeground.color,
            selection: theme.editorSelection.color,
            currentLine: theme.editorCurrentLine.color,
            defaultText: theme.editorForeground.color,
            tokenColors: palette.tokens,
            isDark: theme.tone == .dark,
            font: previewFont
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var previewFont: Font {
        if fontName.isEmpty {
            return .system(size: 11, weight: .medium, design: .monospaced)
        }
        return .custom(fontName, size: 11)
    }
}

private extension Color {
    struct RGBAComponents {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
    }

    var rgbaComponents: RGBAComponents {
#if os(macOS)
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
#else
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
#endif
        return RGBAComponents(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }

    func lerp(to other: Color, fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        let lhs = rgbaComponents
        let rhs = other.rgbaComponents
        return Color(
            red: lhs.red + (rhs.red - lhs.red) * f,
            green: lhs.green + (rhs.green - lhs.green) * f,
            blue: lhs.blue + (rhs.blue - lhs.blue) * f,
            opacity: lhs.opacity + (rhs.opacity - lhs.opacity) * f
        )
    }
}

private extension BinaryInteger {
    var cg: CGFloat { CGFloat(self) }
}

private struct FontChip: View {
    let title: String
    let sampleFontName: String
    let isSelected: Bool
    let onSelect: () -> Void
    var isCustom: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SELECT * FROM table;")
                    .font(sampleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if isCustom {
                    TagBadge(label: "Custom", foreground: Color.accentColor, background: Color.accentColor.opacity(0.18))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var sampleFont: Font {
        if sampleFontName.isEmpty {
            return .system(size: 11, weight: .medium, design: .monospaced)
        }
        return .custom(sampleFontName, size: 11)
    }
}

private struct EditorFontOption: Identifiable {
    let id: String
    let postScriptName: String
    let displayName: String
}

private struct ChipBadge {
    let label: String
    let foreground: Color
    let background: Color
}

private struct OptionalContextMenu<MenuContent: View>: ViewModifier {
    let isEnabled: Bool
    let menu: () -> MenuContent

    func body(content: Content) -> some View {
        if isEnabled {
            content.contextMenu(menuItems: menu)
        } else {
            content
        }
    }
}

private extension View {
    func optionalContextMenu<MenuContent: View>(isEnabled: Bool, @ViewBuilder content: @escaping () -> MenuContent) -> some View {
        modifier(OptionalContextMenu(isEnabled: isEnabled, menu: content))
    }
}

#if os(macOS)
private struct SettingsWindowConfigurator: NSViewRepresentable {
    let themeManager: ThemeManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window: window)
        }
    }

    private func configure(window: NSWindow) {
        if window.titleVisibility != .hidden {
            window.titleVisibility = .hidden
        }
        if window.titlebarAppearsTransparent == false {
            window.titlebarAppearsTransparent = true
        }
    }
}
#endif

#if os(macOS)
final class SystemFontPickerCoordinator: NSObject, ObservableObject {
    private var completion: ((String) -> Void)?

    func present(currentFontName: String, completion: @escaping (String) -> Void) {
        self.completion = completion
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(handleFontChange(_:))
        let initialFont = NSFont(name: currentFontName, size: 14)
            ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        manager.setSelectedFont(initialFont, isMultiple: false)
        let panel = NSFontPanel.shared
        panel.setPanelFont(initialFont, isMultiple: false)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func handleFontChange(_ sender: NSFontManager) {
        let baseFont = sender.selectedFont ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let converted = sender.convert(baseFont)
        completion?(converted.fontName)
    }
}
#else
final class SystemFontPickerCoordinator: ObservableObject {
    func present(currentFontName: String, completion: @escaping (String) -> Void) {
        completion(currentFontName)
    }
}
#endif
private struct PaletteSnippetPreview: View {
    let background: Color
    let gutterBackground: Color
    let gutterForeground: Color
    let selection: Color
    let currentLine: Color
    let defaultText: Color
    let tokenColors: SQLEditorPalette.TokenColors
    let isDark: Bool
    let font: Font

    init(
        background: Color,
        gutterBackground: Color,
        gutterForeground: Color,
        selection: Color,
        currentLine: Color,
        defaultText: Color,
        tokenColors: SQLEditorPalette.TokenColors,
        isDark: Bool,
        font: Font = .system(size: 9, weight: .medium, design: .monospaced)
    ) {
        self.background = background
        self.gutterBackground = gutterBackground
        self.gutterForeground = gutterForeground
        self.selection = selection
        self.currentLine = currentLine
        self.defaultText = defaultText
        self.tokenColors = tokenColors
        self.isDark = isDark
        self.font = font
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isDark ? 0.6 : 1)

            HStack(spacing: 0) {
                lineNumberColumn
                codeColumn
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    private var lineNumberColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            lineNumber(1)
            lineNumber(2)
            lineNumber(3)
        }
        .font(font)
        .frame(width: 26)
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .foregroundStyle(gutterForeground.opacity(isDark ? 0.72 : 0.55))
        .background(gutterBackground.opacity(isDark ? 0.92 : 0.88))
    }

    private var codeColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            codeLine(
                [
                    ("-- palette preview", tokenColors.comment.swiftColor.opacity(isDark ? 0.82 : 0.72))
                ],
                highlight: highlightColor(currentLine, fallbackOpacity: isDark ? 0.25 : 0.16)
            )
            codeLine(
                [
                    ("SELECT ", tokenColors.keyword.swiftColor),
                    ("* ", tokenColors.operatorSymbol.swiftColor),
                    ("FROM ", tokenColors.keyword.swiftColor),
                    ("Echo", tokenColors.identifier.swiftColor),
                    (".", defaultText.opacity(isDark ? 0.75 : 0.6)),
                    ("Table", tokenColors.identifier.swiftColor)
                ],
                highlight: highlightColor(selection, fallbackOpacity: isDark ? 0.38 : 0.26)
            )
            codeLine(
                [
                    ("WHERE ", tokenColors.keyword.swiftColor),
                    ("created_at ", tokenColors.identifier.swiftColor),
                    ("> ", tokenColors.operatorSymbol.swiftColor),
                    ("NOW", tokenColors.function.swiftColor),
                    ("()", defaultText.opacity(isDark ? 0.8 : 0.65)),
                    (";", tokenColors.operatorSymbol.swiftColor.opacity(isDark ? 0.85 : 0.7))
                ]
            )
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background.opacity(isDark ? 0.02 : 0.04))
    }

    private func codeLine(_ segments: [(String, Color)], highlight: Color? = nil) -> some View {
        var attributed = AttributedString()
        for segment in segments {
            var span = AttributedString(segment.0)
            span.font = font
            span.foregroundColor = segment.1
            attributed.append(span)
        }

        return Text(attributed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1.5)
            .padding(.horizontal, 5)
            .background(
                highlight.map {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill($0)
                }
            )
    }

    private func lineNumber(_ value: Int) -> Text {
        Text("\(value)")
    }

    private func highlightColor(_ color: Color, fallbackOpacity: Double) -> Color {
        color.opacity(fallbackOpacity)
    }

    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
}

private struct EditorTokenPreview: View {
    let background: Color
    let gutter: Color
    let gutterAccent: Color
    let gutterForeground: Color
    let selection: Color
    let currentLine: Color
    let tokenColors: SQLEditorPalette.TokenColors
    let isDark: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
                .shadow(color: Color.black.opacity(isDark ? 0.45 : 0.08), radius: isDark ? 4 : 6, y: isDark ? 1 : 3)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isDark ? 0.6 : 1)
                .blendMode(.overlay)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(gutter.opacity(isDark ? 0.94 : 0.82))
                    .frame(width: 18)
                    .overlay(
                        VStack(alignment: .trailing, spacing: 3) {
                            Capsule(style: .continuous)
                                .fill(gutterAccent.opacity(isDark ? 0.6 : 0.5))
                                .frame(width: 8, height: 3)
                            Capsule(style: .continuous)
                                .fill(gutterForeground.opacity(isDark ? 0.52 : 0.35))
                                .frame(width: 9, height: 3)
                            Capsule(style: .continuous)
                                .fill(gutterForeground.opacity(isDark ? 0.48 : 0.3))
                                .frame(width: 10, height: 3)
                        }
                        .padding(.vertical, 10)
                        .padding(.trailing, 3)
                    )

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(currentLine.opacity(isDark ? 0.4 : 0.3))
                        .frame(height: 12)
                        .padding(.top, 10)
                        .padding(.horizontal, 8)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selection.opacity(isDark ? 0.6 : 0.48))
                        .frame(height: 12)
                        .padding(.top, 22)
                        .padding(.horizontal, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        codeLine([
                            (tokenColors.keyword.swiftColor, 18.cg),
                            (tokenColors.identifier.swiftColor, 14.cg),
                            (tokenColors.operatorSymbol.swiftColor, 8.cg),
                            (tokenColors.string.swiftColor, 16.cg)
                        ])
                        codeLine([
                            (tokenColors.comment.swiftColor.opacity(isDark ? 0.78 : 0.68), 48.cg)
                        ])
                        codeLine([
                            (tokenColors.keyword.swiftColor, 16.cg),
                            (tokenColors.identifier.swiftColor, 18.cg),
                            (tokenColors.operatorSymbol.swiftColor, 8.cg),
                            (tokenColors.number.swiftColor, 14.cg)
                        ])
                        codeLine([
                            (tokenColors.function.swiftColor, 14.cg),
                            (tokenColors.plain.swiftColor.opacity(isDark ? 0.75 : 0.58), 20.cg),
                            (tokenColors.comment.swiftColor.opacity(isDark ? 0.6 : 0.5), 14.cg)
                        ])
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func codeLine(_ segments: [(Color, CGFloat)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Capsule(style: .continuous)
                    .fill(segment.0.opacity(isDark ? 0.92 : 0.85))
                    .frame(width: segment.1, height: 5)
            }
            Spacer(minLength: 0)
        }
    }

    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.1)
    }
}

private struct ThemeEditorSheet: View {
    let tone: SQLEditorPalette.Tone
    @Binding var draft: AppColorTheme
    let mode: ThemeEditorMode
    let availablePalettes: [SQLEditorTokenPalette]
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var useCustomAccent = false
    @State private var useStrongHighlight = false
    @State private var useBrightHighlight = false

    private var title: String {
        mode == .create ? "New Theme" : "Edit Theme"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 4)

            ThemePreview(theme: draft, palette: previewPalette, layout: .regular)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemePreview.Layout.regular.cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Form {
                Section("Basics") {
                    TextField("Theme Name", text: $draft.name)

                    HStack {
                        Text("Tone")
                        Spacer()
                        Text(tone == .dark ? "Dark" : "Light")
                            .foregroundStyle(.secondary)
                    }

                    if availablePalettes.isEmpty {
                        Text("No palettes available for this tone.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Default Palette", selection: $draft.defaultPaletteID) {
                            ForEach(availablePalettes, id: \.id) { palette in
                                Text(palette.name).tag(palette.id)
                            }
                        }
                    }
                }

                Section("Accent") {
                    Toggle("Use custom accent colour", isOn: $useCustomAccent)
                        .toggleStyle(.switch)

                    ColorPicker(
                        "Accent colour",
                        selection: accentBinding,
                        supportsOpacity: true
                    )
                    .disabled(!useCustomAccent)
                }

                Section("Window & Surfaces") {
                    ColorPicker("Window background", selection: colorBinding(\AppColorTheme.windowBackground), supportsOpacity: true)
                    ColorPicker("Surface background", selection: colorBinding(\AppColorTheme.surfaceBackground), supportsOpacity: true)
                    ColorPicker("Surface foreground", selection: colorBinding(\AppColorTheme.surfaceForeground), supportsOpacity: true)
                }

                Section("Editor") {
                    ColorPicker("Editor background", selection: colorBinding(\AppColorTheme.editorBackground), supportsOpacity: true)
                    ColorPicker("Editor foreground", selection: colorBinding(\AppColorTheme.editorForeground), supportsOpacity: true)
                    ColorPicker("Gutter background", selection: colorBinding(\AppColorTheme.editorGutterBackground), supportsOpacity: true)
                    ColorPicker("Gutter text", selection: colorBinding(\AppColorTheme.editorGutterForeground), supportsOpacity: true)
                    ColorPicker("Selection highlight", selection: colorBinding(\AppColorTheme.editorSelection), supportsOpacity: true)
                    ColorPicker("Current line", selection: colorBinding(\AppColorTheme.editorCurrentLine), supportsOpacity: true)
                }

                Section("Highlights") {
                    Toggle("Strong highlight", isOn: $useStrongHighlight)
                        .toggleStyle(.switch)
                    ColorPicker(
                        "Strong highlight colour",
                        selection: strongHighlightBinding,
                        supportsOpacity: true
                    )
                    .disabled(!useStrongHighlight)

                    Toggle("Bright highlight", isOn: $useBrightHighlight)
                        .toggleStyle(.switch)
                    ColorPicker(
                        "Bright highlight colour",
                        selection: brightHighlightBinding,
                        supportsOpacity: true
                    )
                    .disabled(!useBrightHighlight)
                }

                Section("Swatches") {
                    ForEach(0..<5, id: \.self) { index in
                        ColorPicker("Swatch \(index + 1)", selection: swatchBinding(index), supportsOpacity: true)
                    }

                    if !availablePalettes.isEmpty {
                        Button("Reset from default palette") {
                            resetSwatchesFromPalette()
                        }
                        .buttonStyle(.link)
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(mode == .create ? "Create Theme" : "Save Changes")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 520, minHeight: 600)
        .padding(24)
        .onAppear {
            ensureSwatchCapacity()
            useCustomAccent = draft.accent != nil
            useStrongHighlight = draft.editorSymbolHighlightStrong != nil
            useBrightHighlight = draft.editorSymbolHighlightBright != nil
        }
        .onChange(of: useCustomAccent) { newValue in
            if newValue {
                if draft.accent == nil {
                    draft.accent = defaultAccent()
                }
            } else {
                draft.accent = nil
            }
        }
        .onChange(of: useStrongHighlight) { newValue in
            if newValue {
                if draft.editorSymbolHighlightStrong == nil {
                    draft.editorSymbolHighlightStrong = draft.editorSelection
                }
            } else {
                draft.editorSymbolHighlightStrong = nil
            }
        }
        .onChange(of: useBrightHighlight) { newValue in
            if newValue {
                if draft.editorSymbolHighlightBright == nil {
                    draft.editorSymbolHighlightBright = draft.editorSelection
                }
            } else {
                draft.editorSymbolHighlightBright = nil
            }
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<AppColorTheme, ColorRepresentable>) -> Binding<Color> {
        Binding(
            get: { draft[keyPath: keyPath].color },
            set: { draft[keyPath: keyPath] = ColorRepresentable(color: $0) }
        )
    }

    private func optionalColorBinding(_ keyPath: WritableKeyPath<AppColorTheme, ColorRepresentable?>) -> Binding<Color> {
        Binding(
            get: { (draft[keyPath: keyPath] ?? draft.editorSelection).color },
            set: { draft[keyPath: keyPath] = ColorRepresentable(color: $0) }
        )
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { (draft.accent ?? defaultAccent()).color },
            set: { draft.accent = ColorRepresentable(color: $0) }
        )
    }

    private var strongHighlightBinding: Binding<Color> {
        optionalColorBinding(\AppColorTheme.editorSymbolHighlightStrong)
    }

    private var brightHighlightBinding: Binding<Color> {
        optionalColorBinding(\AppColorTheme.editorSymbolHighlightBright)
    }

    private func swatchBinding(_ index: Int) -> Binding<Color> {
        ensureSwatchCapacity()
        return Binding(
            get: { draft.swatchColors[index].color },
            set: { draft.swatchColors[index] = ColorRepresentable(color: $0) }
        )
    }

    private func ensureSwatchCapacity() {
        if draft.swatchColors.count < 5 {
            let needed = 5 - draft.swatchColors.count
            draft.swatchColors.append(contentsOf: Array(repeating: defaultAccent(), count: needed))
        }
    }

    private func resetSwatchesFromPalette() {
        if let palette = availablePalettes.first(where: { $0.id == draft.defaultPaletteID }) {
            draft.swatchColors = palette.showcaseColors.map { ColorRepresentable(color: $0) }
        } else {
            draft.swatchColors = []
        }
        ensureSwatchCapacity()
    }

    private func defaultAccent() -> ColorRepresentable {
        if let palette = availablePalettes.first(where: { $0.id == draft.defaultPaletteID }) {
            return ColorRepresentable(color: palette.tokens.keyword.swiftColor)
        }
        return draft.accent ?? draft.surfaceForeground
    }

    private var previewPalette: SQLEditorTokenPalette? {
        availablePalettes.first(where: { $0.id == draft.defaultPaletteID })
    }
}

private struct TokenPaletteEditorSheet: View {
    @Binding var tone: SQLEditorPalette.Tone
    @Binding var toneMode: PaletteToneMode
    @Binding var draft: SQLEditorTokenPalette
    let mode: PaletteEditorMode
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var title: String {
        mode == .create ? "New Palette" : "Edit Palette"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            ScrollView {
                Form {
                    Section("Basics") {
                    TextField("Palette Name", text: $draft.name)

                    if mode == .create {
                        Picker("Tone", selection: $toneMode) {
                            Text("Light").tag(PaletteToneMode.light)
                            Text("Dark").tag(PaletteToneMode.dark)
                            Text("Both").tag(PaletteToneMode.both)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: toneMode) { newValue in
                            switch newValue {
                            case .light: tone = .light
                            case .dark: tone = .dark
                            case .both: tone = .light
                            }
                        }
                    } else {
                        HStack {
                            Text("Tone")
                            Spacer()
                            Text(tone == .dark ? "Dark" : "Light")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 4)
                    }
                }

                    Section("Tokens") {
                        tokenRow(label: "Keywords", keyPath: \SQLEditorPalette.TokenColors.keyword)
                        tokenRow(label: "Strings", keyPath: \SQLEditorPalette.TokenColors.string)
                        tokenRow(label: "Numbers", keyPath: \SQLEditorPalette.TokenColors.number)
                        tokenRow(label: "Comments", keyPath: \SQLEditorPalette.TokenColors.comment)
                        tokenRow(label: "Functions", keyPath: \SQLEditorPalette.TokenColors.function)
                        tokenRow(label: "Operators", keyPath: \SQLEditorPalette.TokenColors.operatorSymbol)
                        tokenRow(label: "Identifiers", keyPath: \SQLEditorPalette.TokenColors.identifier)
                        tokenRow(label: "Plain Text", keyPath: \SQLEditorPalette.TokenColors.plain)
                    }

                    Section("Query Results") {
                        resultGridRow(label: "Null", keyPath: \SQLEditorTokenPalette.ResultGridColors.null)
                        resultGridRow(label: "Numbers", keyPath: \SQLEditorTokenPalette.ResultGridColors.numeric)
                        resultGridRow(label: "Booleans", keyPath: \SQLEditorTokenPalette.ResultGridColors.boolean)
                        resultGridRow(label: "Temporal", keyPath: \SQLEditorTokenPalette.ResultGridColors.temporal)
                        resultGridRow(label: "Binary", keyPath: \SQLEditorTokenPalette.ResultGridColors.binary)
                        resultGridRow(label: "Identifiers", keyPath: \SQLEditorTokenPalette.ResultGridColors.identifier)
                        resultGridRow(label: "JSON", keyPath: \SQLEditorTokenPalette.ResultGridColors.json)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .disabled(isSaving)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(mode == .create ? "Create Palette" : "Save Changes")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 460, minHeight: 560)
        .padding(24)
        .onAppear {
            if mode == .create {
                switch toneMode {
                case .light:
                    tone = .light
                case .dark:
                    tone = .dark
                case .both:
                    tone = .light
                }
            } else {
                toneMode = tone == .dark ? .dark : .light
            }
        }
    }

    private func tokenColorBinding(_ keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Color> {
        Binding(
            get: { draft.tokens[keyPath: keyPath].swiftColor },
            set: { newValue in
                var style = draft.tokens[keyPath: keyPath]
                style.color = ColorRepresentable(color: newValue)
                draft.tokens[keyPath: keyPath] = style
            }
        )
    }

    private func tokenBoldBinding(_ keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Bool> {
        Binding(
            get: { draft.tokens[keyPath: keyPath].isBold },
            set: { newValue in
                var style = draft.tokens[keyPath: keyPath]
                style.isBold = newValue
                draft.tokens[keyPath: keyPath] = style
            }
        )
    }

    private func tokenItalicBinding(_ keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Bool> {
        Binding(
            get: { draft.tokens[keyPath: keyPath].isItalic },
            set: { newValue in
                var style = draft.tokens[keyPath: keyPath]
                style.isItalic = newValue
                draft.tokens[keyPath: keyPath] = style
            }
        )
    }

    @ViewBuilder
    private func tokenRow(
        label: String,
        keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>
    ) -> some View {
        HStack(spacing: 16) {
            Text(label)
            Spacer()
            ColorPicker(
                label,
                selection: tokenColorBinding(keyPath),
                supportsOpacity: true
            )
            .labelsHidden()
            .frame(width: 130, alignment: .trailing)
            Toggle("Italic", isOn: tokenItalicBinding(keyPath))
                .toggleStyle(.checkbox)
            Toggle("Bold", isOn: tokenBoldBinding(keyPath))
                .toggleStyle(.checkbox)
        }
        .font(.caption)
        .padding(.vertical, 4)
    }

    private func resultGridColorBinding(_ keyPath: WritableKeyPath<SQLEditorTokenPalette.ResultGridColors, SQLEditorTokenPalette.ResultGridStyle>) -> Binding<Color> {
        Binding(
            get: { draft.resultGrid[keyPath: keyPath].swiftColor },
            set: { newValue in
                var style = draft.resultGrid[keyPath: keyPath]
                style.color = ColorRepresentable(color: newValue)
                draft.resultGrid[keyPath: keyPath] = style
            }
        )
    }

    private func resultGridBoldBinding(_ keyPath: WritableKeyPath<SQLEditorTokenPalette.ResultGridColors, SQLEditorTokenPalette.ResultGridStyle>) -> Binding<Bool> {
        Binding(
            get: { draft.resultGrid[keyPath: keyPath].isBold },
            set: { newValue in
                var style = draft.resultGrid[keyPath: keyPath]
                style.isBold = newValue
                draft.resultGrid[keyPath: keyPath] = style
            }
        )
    }

    private func resultGridItalicBinding(_ keyPath: WritableKeyPath<SQLEditorTokenPalette.ResultGridColors, SQLEditorTokenPalette.ResultGridStyle>) -> Binding<Bool> {
        Binding(
            get: { draft.resultGrid[keyPath: keyPath].isItalic },
            set: { newValue in
                var style = draft.resultGrid[keyPath: keyPath]
                style.isItalic = newValue
                draft.resultGrid[keyPath: keyPath] = style
            }
        )
    }

    @ViewBuilder
    private func resultGridRow(
        label: String,
        keyPath: WritableKeyPath<SQLEditorTokenPalette.ResultGridColors, SQLEditorTokenPalette.ResultGridStyle>
    ) -> some View {
        HStack(spacing: 16) {
            Text(label)
            Spacer()
            ColorPicker(
                label,
                selection: resultGridColorBinding(keyPath),
                supportsOpacity: true
            )
            .labelsHidden()
            .frame(width: 130, alignment: .trailing)
            Toggle("Italic", isOn: resultGridItalicBinding(keyPath))
                .toggleStyle(.checkbox)
            Toggle("Bold", isOn: resultGridBoldBinding(keyPath))
                .toggleStyle(.checkbox)
        }
        .font(.caption)
        .padding(.vertical, 4)
    }
}
private struct SwatchStripView: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.92))
                    .frame(width: 14, height: 9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(color.opacity(0.35), lineWidth: 0.8)
                    )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        .blendMode(.overlay)
                )
        )
    }
}

private struct TagBadge: View {
    let label: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(label.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(Capsule())
    }
}

struct ApplicationCacheSettingsView: View {
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager
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
        .background(themeManager.surfaceBackgroundColor)
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

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}
