import SwiftUI
import Foundation
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
    @State private var paletteEditorMode: PaletteEditorMode = .create
    @State private var paletteEditorDraft = SQLEditorTokenPalette(from: SQLEditorPalette.aurora)

    @State private var isThemeEditorPresented = false
    @State private var isPaletteEditorPresented = false


    var body: some View {
        Form {
            appearanceModeSection

            if shouldShowSection(for: .light) {
                toneSection(for: .light, title: "Light Appearance")
            }

            if shouldShowSection(for: .dark) {
                toneSection(for: .dark, title: "Dark Appearance")
            }

            accentSection
            workspaceSection
            resultsGridSection
            editorDisplaySection
            informationSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
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
                tone: paletteEditorTone,
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(appearanceModeOptions) { option in
                        AppearanceModeCard(
                            option: option,
                            isSelected: appearanceModeBinding.wrappedValue == option.mode,
                            onSelect: { appearanceModeBinding.wrappedValue = option.mode }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func toneSection(for tone: SQLEditorPalette.Tone, title: String) -> some View {
        Section(title) {
            themeGrid(for: tone)
            paletteGrid(for: tone)

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

    private func themeGrid(for tone: SQLEditorPalette.Tone) -> some View {
        let themes = availableThemes(for: tone)
        let selectedThemeID = appModel.globalSettings.activeThemeID(for: tone)
        let autoTheme = appModel.globalSettings.themeMatchingCurrentPalette(for: tone)
            ?? themeManager.theme(for: tone)
        let defaultPalette = appModel.globalSettings.defaultPalette(for: tone)

        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ThemeSelectionCard(
                        title: "Match Palette Default",
                        subtitle: defaultPalette?.name ?? "Use palette colours",
                        theme: autoTheme,
                        palette: defaultPalette,
                        isSelected: selectedThemeID == nil,
                        isBusy: isUpdatingTheme && selectedThemeID == nil,
                        badge: ThemeSelectionCard.Badge(label: "Auto", style: .default),
                        onSelect: { selectTheme(nil, tone: tone) },
                        style: .compact
                    ) {
                        EmptyView()
                    }
                    .disabled(isUpdatingTheme)

                    ForEach(themes) { theme in
                        let palette = palette(for: theme.defaultPaletteID)
                        ThemeSelectionCard(
                            title: theme.name,
                            subtitle: palette?.name,
                            theme: theme,
                            palette: palette,
                            isSelected: selectedThemeID == theme.id,
                            isBusy: isUpdatingTheme && selectedThemeID == theme.id,
                            badge: theme.isCustom ? ThemeSelectionCard.Badge(label: "Custom", style: .secondary) : nil,
                            onSelect: { selectTheme(theme.id, tone: tone, defaultPaletteID: theme.defaultPaletteID) },
                            style: .compact
                        ) {
                            if theme.isCustom {
                                Button("Edit Theme…") { startEditingTheme(theme, tone: tone) }
                                Button("Duplicate…") { startDuplicatingTheme(theme, tone: tone) }
                                Button("Delete", role: .destructive) { themePendingDeletion = theme }
                            } else {
                                Button("Duplicate…") { startDuplicatingTheme(theme, tone: tone) }
                            }
                        }
                        .disabled(isUpdatingTheme)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Button("New Theme…") { startCreatingTheme(tone: tone) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdatingTheme)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedThemeID)
    }

    private func paletteGrid(for tone: SQLEditorPalette.Tone) -> some View {
        let palettes = availablePalettes(for: tone)
        let selectedPaletteID = appModel.globalSettings.defaultPaletteID(for: tone)

        return VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if palettes.isEmpty {
                        paletteEmptyStateCard
                    } else {
                        ForEach(palettes, id: \.id) { palette in
                            PaletteSelectionCard(
                                palette: palette,
                                isSelected: selectedPaletteID == palette.id,
                                isBusy: isUpdatingPalette && selectedPaletteID == palette.id,
                                onSelect: { selectPalette(palette, tone: tone) }
                            ) {
                                if palette.kind == .custom {
                                    Button("Edit Palette…") { startEditingPalette(palette, tone: tone) }
                                    Button("Duplicate…") { startDuplicatingPalette(palette, tone: tone) }
                                    Button("Delete", role: .destructive) { palettePendingDeletion = palette }
                                } else {
                                    Button("Duplicate…") { startDuplicatingPalette(palette, tone: tone) }
                                }
                            }
                            .disabled(isUpdatingPalette)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Button("New Palette…") { startCreatingPalette(tone: tone) }
                    .buttonStyle(.bordered)
                    .disabled(isUpdatingPalette)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPaletteID)
    }

    @ViewBuilder
    private var paletteEmptyStateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No palettes available for this tone.")
                .font(.system(size: 12, weight: .semibold))
            Text("Create a palette to customise SQL syntax colours.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: ThemePreview.Layout.compact.size.width + 24, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
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

    private var workspaceSection: some View {
        Section("Workspace") {
            Toggle("Match workspace tabs to editor theme", isOn: themeTabsBinding)
                .toggleStyle(.switch)

            Text("Adjust the workspace tab strip to reuse the active SQL editor theme's colors.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var resultsGridSection: some View {
        Section("Results Grid") {
            Toggle("Use application theme", isOn: themeResultsGridBinding)
                .toggleStyle(.switch)

            Text("When enabled, the results table adopts the active window theme's background and foreground colors.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Toggle("Show alternate row shading", isOn: alternateRowShadingBinding)
                .toggleStyle(.switch)

            Text("Applies subtle striping to result rows to aid scanning. Available in both themed and system appearance modes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        paletteEditorMode = .edit
        var draft = palette
        draft.tone = tone
        draft.kind = .custom
        paletteEditorDraft = draft
        isPaletteEditorPresented = true
    }

    private func startDuplicatingPalette(_ palette: SQLEditorTokenPalette, tone: SQLEditorPalette.Tone) {
        paletteEditorTone = tone
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
        var draft = paletteEditorDraft
        draft.tone = paletteEditorTone
        draft.kind = .custom
        draft.name = sanitizedName(draft.name, fallback: paletteEditorTone == .dark ? "Custom Dark Palette" : "Custom Light Palette")
        if paletteEditorMode == .create && !draft.id.hasPrefix("custom-") {
            draft.id = "custom-\(UUID().uuidString)"
        }
        let shouldSelect = paletteEditorMode == .create
        Task { @MainActor in
            await appModel.upsertCustomPalette(draft)
            if shouldSelect || appModel.globalSettings.defaultPaletteID(for: paletteEditorTone) == draft.id {
                await appModel.setDefaultEditorPalette(to: draft.id, for: paletteEditorTone)
            }
            isUpdatingPalette = false
            isPaletteEditorPresented = false
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

    private func availableThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        appModel.globalSettings.availableThemes(for: tone)
    }

    private func availablePalettes(for tone: SQLEditorPalette.Tone) -> [SQLEditorTokenPalette] {
        appModel.globalSettings.availablePalettes.filter { $0.tone == tone }
    }

    private var appearanceModeOptions: [AppearanceModeOption] {
        let light = appearanceThemePreview(for: .light)
        let dark = appearanceThemePreview(for: .dark)

        return [
            AppearanceModeOption(
                mode: .system,
                title: "System",
                subtitle: "Matches macOS appearance",
                preview: .dual(light: light, dark: dark)
            ),
            AppearanceModeOption(
                mode: .light,
                title: "Light",
                subtitle: "Always use light chrome",
                preview: .single(light)
            ),
            AppearanceModeOption(
                mode: .dark,
                title: "Dark",
                subtitle: "Always use dark chrome",
                preview: .single(dark)
            )
        ]
    }

    private func appearanceThemePreview(for tone: SQLEditorPalette.Tone) -> AppearanceThemePreview {
        let theme = appModel.globalSettings.theme(
            withID: appModel.globalSettings.activeThemeID(for: tone),
            tone: tone
        ) ?? themeManager.theme(for: tone)
        let resolvedPalette = palette(for: theme.defaultPaletteID)
            ?? appModel.globalSettings.defaultPalette(for: tone)
        return AppearanceThemePreview(theme: theme, palette: resolvedPalette)
    }

    private func palette(for id: String?) -> SQLEditorTokenPalette? {
        guard let id else { return nil }
        return appModel.globalSettings.palette(withID: id)
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

private struct ThemeSelectionCard<ContextMenuContent: View>: View {
    enum Style {
        case grid
        case compact
    }

    struct Badge {
        enum Style {
            case `default`
            case secondary
        }

        let label: String
        let style: Style
    }

    let title: String
    let subtitle: String?
    let theme: AppColorTheme?
    let palette: SQLEditorTokenPalette?
    let isSelected: Bool
    let isBusy: Bool
    let badge: Badge?
    let onSelect: () -> Void
    var style: Style = .grid
    @ViewBuilder var contextMenu: () -> ContextMenuContent

    var body: some View {
        let previewLayout: ThemePreview.Layout = style == .grid ? .regular : .compact

        return Button(action: { onSelect() }) {
            VStack(alignment: .center, spacing: 9) {
                ThemePreview(
                    theme: theme,
                    palette: palette,
                    layout: previewLayout
                )
                .frame(width: previewLayout.size.width, height: previewLayout.size.height)
                .overlay(alignment: .topLeading) {
                    if let badge {
                        badgeView(for: badge)
                            .padding(10)
                    }
                }

                VStack(alignment: .center, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(cardPadding)
            .frame(width: cardWidth(for: previewLayout))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : inactiveBorderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu(menuItems: contextMenu)
        .overlay {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var cardBackground: Color {
        if let theme {
            return theme.surfaceBackground.color.opacity(style == .grid ? 0.9 : 0.75)
        }
        return Color.primary.opacity(style == .grid ? 0.06 : 0.05)
    }

    private var inactiveBorderColor: Color {
        if let theme {
            return theme.surfaceForeground.color.opacity(0.15)
        }
        return Color.primary.opacity(0.08)
    }

    @ViewBuilder
    private func badgeView(for badge: Badge) -> some View {
        switch badge.style {
        case .default:
            DefaultBadge(label: badge.label)
        case .secondary:
            SecondaryBadge(label: badge.label)
        }
    }

    private var cardPadding: CGFloat {
        style == .grid ? 12 : 9
    }

    private func cardWidth(for layout: ThemePreview.Layout) -> CGFloat {
        layout.size.width + (cardPadding * 2)
    }
}

private struct AppearanceModeCard: View {
    let option: AppearanceModeOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: { onSelect() }) {
            VStack(alignment: .leading, spacing: 10) {
                preview

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(width: ThemePreview.Layout.compact.size.width + 20, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        switch option.preview {
        case .single(let preview):
            ThemePreview(theme: preview.theme, palette: preview.palette, layout: .compact)
        case .dual(let light, let dark):
            ZStack {
                ThemePreview(theme: dark.theme, palette: dark.palette, layout: .compact)
                    .scaleEffect(0.92)
                    .offset(x: 18, y: 4)
                    .opacity(0.82)
                ThemePreview(theme: light.theme, palette: light.palette, layout: .compact)
                    .scaleEffect(0.92)
                    .offset(x: -12, y: -4)
            }
        }
    }

    private var cardBackground: Color {
        switch option.mode {
        case .dark:
            return Color.white.opacity(0.05)
        case .light:
            return Color.primary.opacity(0.05)
        case .system:
            return Color.primary.opacity(0.045)
        }
    }

    private var borderColor: Color {
        Color.primary.opacity(0.08)
    }
}

private struct PaletteSelectionCard<ContextMenuContent: View>: View {
    let palette: SQLEditorTokenPalette
    let isSelected: Bool
    let isBusy: Bool
    let onSelect: () -> Void
    @ViewBuilder var contextMenu: () -> ContextMenuContent

    var body: some View {
        Button(action: { onSelect() }) {
            VStack(alignment: .center, spacing: 8) {
                PaletteSnippetPreview(
                    background: basePalette.background.color,
                    gutterBackground: basePalette.gutterBackground.color,
                    gutterForeground: basePalette.gutterText.color,
                    selection: basePalette.selection.color,
                    currentLine: basePalette.currentLine.color,
                    defaultText: basePalette.text.color,
                    tokenColors: palette.tokens,
                    isDark: palette.tone == .dark
                )
                .frame(width: snippetSize.width, height: snippetSize.height)

                SwatchStripView(colors: Array(palette.showcaseColors.prefix(6)))
                    .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 3) {
                    Text(palette.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(palette.tone == .dark ? "Dark palette" : "Light palette")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(cardPadding)
            .frame(width: cardWidth, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu(menuItems: contextMenu)
        .overlay(alignment: .topLeading) {
            if palette.kind == .custom {
                SecondaryBadge(label: "Custom")
                    .padding(10)
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var cardBackground: Color {
        palette.tone == .dark ? Color.white.opacity(0.05) : Color.primary.opacity(0.05)
    }

    private var borderColor: Color {
        palette.tone == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.08)
    }

    private var basePalette: SQLEditorPalette {
        SQLEditorPalette.palette(withID: palette.id)
            ?? (palette.tone == .dark ? .midnight : .aurora)
    }

    private var cardPadding: CGFloat { 12 }

    private var cardWidth: CGFloat {
        ThemePreview.Layout.compact.size.width + (cardPadding * 2)
    }

    private var snippetSize: CGSize {
        CGSize(width: ThemePreview.Layout.compact.size.width, height: 58)
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

    private var defaultPalette: SQLEditorPalette {
        isDark ? .midnight : .aurora
    }

    private var basePalette: SQLEditorPalette {
        if let theme, let resolved = SQLEditorPalette.palette(withID: theme.defaultPaletteID) {
            return resolved
        }
        if let palette, let resolved = SQLEditorPalette.palette(withID: palette.id) {
            return resolved
        }
        return defaultPalette
    }

    private var windowColor: Color {
        theme?.windowBackground.color ?? basePalette.background.color
    }

    private var surfaceColor: Color {
        theme?.surfaceBackground.color ?? basePalette.gutterBackground.color
    }

    private var accentColor: Color {
        if let accent = theme?.accent?.color {
            return accent
        }
        return palette?.tokens.keyword.color ?? basePalette.tokens.keyword.color
    }

#if DEBUG
    private func reportSizeIfNeeded(_ size: CGSize) {
        DispatchQueue.main.async {
            let deltaWidth = abs(size.width - debugLoggedSize.width)
            let deltaHeight = abs(size.height - debugLoggedSize.height)
            guard deltaWidth > 0.5 || deltaHeight > 0.5 else { return }
            debugLoggedSize = size
            let width = String(format: "%.1f", size.width)
            let height = String(format: "%.1f", size.height)
            print("[ThemePreview] layout=\(layout) size=\(width)x\(height)")
        }
    }
#endif
}

private struct PaletteSnippetPreview: View {
    let background: Color
    let gutterBackground: Color
    let gutterForeground: Color
    let selection: Color
    let currentLine: Color
    let defaultText: Color
    let tokenColors: SQLEditorPalette.TokenColors
    let isDark: Bool

    private let font: Font = .system(size: 9, weight: .medium, design: .monospaced)

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
                    ("-- palette preview", tokenColors.comment.color.opacity(isDark ? 0.82 : 0.72))
                ],
                highlight: highlightColor(currentLine, fallbackOpacity: isDark ? 0.25 : 0.16)
            )
            codeLine(
                [
                    ("SELECT ", tokenColors.keyword.color),
                    ("* ", tokenColors.operatorSymbol.color),
                    ("FROM ", tokenColors.keyword.color),
                    ("Echo", tokenColors.identifier.color),
                    (".", defaultText.opacity(isDark ? 0.75 : 0.6)),
                    ("Table", tokenColors.identifier.color)
                ],
                highlight: highlightColor(selection, fallbackOpacity: isDark ? 0.38 : 0.26)
            )
            codeLine(
                [
                    ("WHERE ", tokenColors.keyword.color),
                    ("created_at ", tokenColors.identifier.color),
                    ("> ", tokenColors.operatorSymbol.color),
                    ("NOW", tokenColors.function.color),
                    ("()", defaultText.opacity(isDark ? 0.8 : 0.65)),
                    (";", tokenColors.operatorSymbol.color.opacity(isDark ? 0.85 : 0.7))
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
                            (tokenColors.keyword.color, 18),
                            (tokenColors.identifier.color, 14),
                            (tokenColors.operatorSymbol.color, 8),
                            (tokenColors.string.color, 16)
                        ])
                        codeLine([
                            (tokenColors.comment.color.opacity(isDark ? 0.78 : 0.68), 48)
                        ])
                        codeLine([
                            (tokenColors.keyword.color, 16),
                            (tokenColors.identifier.color, 18),
                            (tokenColors.operatorSymbol.color, 8),
                            (tokenColors.number.color, 14)
                        ])
                        codeLine([
                            (tokenColors.function.color, 14),
                            (tokenColors.plain.color.opacity(isDark ? 0.75 : 0.58), 20),
                            (tokenColors.comment.color.opacity(isDark ? 0.6 : 0.5), 14)
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
            return ColorRepresentable(color: palette.tokens.keyword.color)
        }
        return draft.accent ?? draft.surfaceForeground
    }

    private var previewPalette: SQLEditorTokenPalette? {
        availablePalettes.first(where: { $0.id == draft.defaultPaletteID })
    }
}

private struct TokenPaletteEditorSheet: View {
    let tone: SQLEditorPalette.Tone
    @Binding var draft: SQLEditorTokenPalette
    let mode: PaletteEditorMode
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private var title: String {
        mode == .create ? "New Palette" : "Edit Palette"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Basics") {
                    TextField("Palette Name", text: $draft.name)

                    HStack {
                        Text("Tone")
                        Spacer()
                        Text(tone == .dark ? "Dark" : "Light")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tokens") {
                    tokenColorRow(label: "Keywords", binding: tokenBinding(\SQLEditorPalette.TokenColors.keyword))
                    tokenColorRow(label: "Strings", binding: tokenBinding(\SQLEditorPalette.TokenColors.string))
                    tokenColorRow(label: "Numbers", binding: tokenBinding(\SQLEditorPalette.TokenColors.number))
                    tokenColorRow(label: "Comments", binding: tokenBinding(\SQLEditorPalette.TokenColors.comment))
                    tokenColorRow(label: "Functions", binding: tokenBinding(\SQLEditorPalette.TokenColors.function))
                    tokenColorRow(label: "Operators", binding: tokenBinding(\SQLEditorPalette.TokenColors.operatorSymbol))
                    tokenColorRow(label: "Identifiers", binding: tokenBinding(\SQLEditorPalette.TokenColors.identifier))
                    tokenColorRow(label: "Plain text", binding: tokenBinding(\SQLEditorPalette.TokenColors.plain))
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
                        Text(mode == .create ? "Create Palette" : "Save Changes")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 420, minHeight: 480)
        .padding(24)
    }

    private func tokenBinding(_ keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, ColorRepresentable>) -> Binding<Color> {
        Binding(
            get: { draft.tokens[keyPath: keyPath].color },
            set: { draft.tokens[keyPath: keyPath] = ColorRepresentable(color: $0) }
        )
    }

    private func tokenColorRow(label: String, binding: Binding<Color>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker(label, selection: binding, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 130, alignment: .trailing)
        }
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

private struct AppearanceThemePreview {
    let theme: AppColorTheme
    let palette: SQLEditorTokenPalette?
}

private struct AppearanceModeOption: Identifiable {
    enum Preview {
        case single(AppearanceThemePreview)
        case dual(light: AppearanceThemePreview, dark: AppearanceThemePreview)
    }

    var id: AppearanceMode { mode }
    let mode: AppearanceMode
    let title: String
    let subtitle: String
    let preview: Preview
}

private struct DefaultBadge: View {
    var label: String = "Default"

    var body: some View {
        TagBadge(
            label: label,
            foreground: Color.accentColor,
            background: Color.accentColor.opacity(0.18)
        )
    }
}

private struct SecondaryBadge: View {
    let label: String

    var body: some View {
        TagBadge(
            label: label,
            foreground: Color.secondary,
            background: Color.secondary.opacity(0.18)
        )
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
