import SwiftUI
import Foundation
import AppKit

struct AppearanceSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            appearanceModeSection
            accentColorSection
            sidebarSection
            editorFontSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private var appearanceModeSection: some View {
        Section("Appearance Mode") {
            AppearanceModePicker(selection: appearanceModeBinding)
        }
    }

    private var accentColorSection: some View {
        Section("Accent Color") {
            AccentColorSourceRow(selection: accentColorSourceBinding)


            if projectStore.globalSettings.accentColorSource == .custom {
                LabeledContent("Accent Color") {
                    AccentColorPalette(selection: customAccentColorHexBinding)
                }
            }
        }
    }

    private var sidebarSection: some View {
        Section("Sidebar") {
            Toggle("Colored sidebar icons", isOn: Binding(
                get: { projectStore.globalSettings.sidebarColoredIcons },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.sidebarColoredIcons = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))
        }
    }

    private var editorFontSection: some View {
        Section("Editor Font") {
            MonospacedFontPicker(
                selectedFamily: Binding(
                    get: { projectStore.globalSettings.defaultEditorFontFamily },
                    set: { newValue in
                        var settings = projectStore.globalSettings
                        settings.defaultEditorFontFamily = newValue
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                ),
                fontSize: projectStore.globalSettings.defaultEditorFontSize
            )

            LabeledContent("Font Size") {
                Picker("", selection: Binding(
                    get: { projectStore.globalSettings.defaultEditorFontSize },
                    set: { newValue in
                        var settings = projectStore.globalSettings
                        settings.defaultEditorFontSize = newValue
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                )) {
                    ForEach(Self.fontSizeOptions, id: \.self) { size in
                        Text(Self.fontSizeLabel(size)).tag(size)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 100, idealWidth: 120, maxWidth: 160, alignment: .trailing)
            }

            Toggle("Enable Ligatures", isOn: Binding(
                get: { projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))
        }
    }

    // MARK: - Constants

    private static let fontSizeOptions: [Double] = stride(from: 8.0, through: 24.0, by: 0.5).map { $0 }

    private static func fontSizeLabel(_ size: Double) -> String {
        size.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(size)),0 pt"
            : String(format: "%.1f pt", size).replacingOccurrences(of: ".", with: ",")
    }

    // MARK: - Bindings

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { projectStore.globalSettings.appearanceMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.appearanceMode = newValue
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    appearanceStore.applyAppearanceMode(newValue)
                }
            }
        )
    }

    private var accentColorSourceBinding: Binding<AccentColorSource> {
        Binding(
            get: { projectStore.globalSettings.accentColorSource },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.accentColorSource = newValue
                let hex = settings.customAccentColorHex
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    switch newValue {
                    case .system, .connection:
                        appearanceStore.setAccentColor(nil)
                    case .custom:
                        if let hex, let color = Color(hex: hex) {
                            appearanceStore.setAccentColor(color)
                        }
                    }
                }
            }
        )
    }

    private var customAccentColorHexBinding: Binding<String> {
        Binding(
            get: { projectStore.globalSettings.customAccentColorHex ?? "" },
            set: { newHex in
                var settings = projectStore.globalSettings
                settings.customAccentColorHex = newHex.isEmpty ? nil : newHex
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    if let color = Color(hex: newHex) {
                        appearanceStore.setAccentColor(color)
                    }
                }
            }
        )
    }
}

// MARK: - Appearance Mode Picker with Previews

private struct AppearanceModePicker: View {
    @Binding var selection: AppearanceMode

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                AppearanceModeCard(mode: mode, isSelected: selection == mode)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = mode }
                    }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }
}

private struct AppearanceModeCard: View {
    let mode: AppearanceMode
    let isSelected: Bool

    private var previewScheme: ColorScheme? {
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            previewThumbnail
                .frame(width: 120, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.accent : .clear, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            Text(mode.displayName)
                .font(TypographyTokens.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var previewThumbnail: some View {
        ZStack {
            switch mode {
            case .light:
                miniWindowPreview(bg: Color(white: 0.96), sidebar: Color(white: 0.91), content: Color.white)
            case .dark:
                miniWindowPreview(bg: Color(white: 0.15), sidebar: Color(white: 0.12), content: Color(white: 0.18))
            case .system:
                HStack(spacing: 0) {
                    miniWindowPreview(bg: Color(white: 0.96), sidebar: Color(white: 0.91), content: Color.white)
                        .clipShape(Rectangle())
                    miniWindowPreview(bg: Color(white: 0.15), sidebar: Color(white: 0.12), content: Color(white: 0.18))
                        .clipShape(Rectangle())
                }
            }
        }
    }

    private func miniWindowPreview(bg: Color, sidebar: Color, content: Color) -> some View {
        ZStack(alignment: .topLeading) {
            bg
            HStack(spacing: 0) {
                sidebar.frame(width: 30)
                VStack(spacing: 0) {
                    bg.frame(height: 10)
                    content
                }
            }
            // Traffic lights
            HStack(spacing: SpacingTokens.xxxs) {
                Circle().fill(ColorTokens.Status.error.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(ColorTokens.Status.warning.opacity(0.8)).frame(width: 5, height: 5)
                Circle().fill(ColorTokens.Status.success.opacity(0.8)).frame(width: 5, height: 5)
            }
            .padding(.top, SpacingTokens.xxs)
            .padding(.leading, SpacingTokens.xxs)
        }
    }
}

// MARK: - Accent Color Source Row

private struct AccentColorSourceRow: View {
    @Binding var selection: AccentColorSource
    @State private var isPopoverPresented = false

    private static let sourceDescriptions: [(source: AccentColorSource, summary: String)] = [
        (.system, "Uses your macOS accent color"),
        (.connection, "Tints with the active connection color"),
        (.custom, "Pick a specific accent color"),
    ]

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Picker("", selection: $selection) {
                    ForEach(AccentColorSource.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.secondary)
                .popover(isPresented: $isPopoverPresented,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(Self.sourceDescriptions, id: \.source) { item in
                            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                                Text(item.source.displayName)
                                    .font(TypographyTokens.standard.weight(.semibold))
                                    .frame(width: 80, alignment: .leading)
                                Text(item.summary)
                                    .font(TypographyTokens.standard)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .frame(width: 340)
                }
            }
        } label: {
            Text("Accent color source")
        }
    }
}

// MARK: - Accent Color Palette

private struct AccentColorPalette: View {
    @Binding var selection: String

    private static let presets: [(name: String, hex: String)] = [
        ("Blue", "5A9CDE"),
        ("Green", "6EAE72"),
        ("Orange", "E8943A"),
        ("Purple", "9B72CF"),
        ("Pink", "D4687A"),
    ]

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selection) ?? ColorTokens.accent },
            set: { color in
                if let hex = color.toHex() {
                    selection = hex.replacingOccurrences(of: "#", with: "")
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(Self.presets, id: \.hex) { preset in
                let isSelected = selection.uppercased() == preset.hex.uppercased()
                Circle()
                    .fill(Color(hex: preset.hex) ?? ColorTokens.accent)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(TypographyTokens.compact.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().strokeBorder(ColorTokens.Text.primary.opacity(0.15), lineWidth: 0.5))
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { selection = preset.hex }
                    }
            }

            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
        }
    }
}
