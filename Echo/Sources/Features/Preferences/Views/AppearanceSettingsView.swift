import SwiftUI
import Foundation
import AppKit

struct AppearanceSettingsView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(AppearanceStore.self) var appearanceStore

    var body: some View {
        Form {
            Section {
                PropertyRow(title: "Appearance") {
                    AppearanceModePicker(selection: appearanceModeBinding)
                }

                PropertyRow(
                    title: "Explorer Sidebar",
                    subtitle: "Choose the row density for the explorer sidebar."
                ) {
                    SidebarDensityPicker(selection: sidebarDensityBinding)
                }

                PropertyRow(
                    title: "Sidebar Icons",
                    subtitle: "Choose your preferred look for sidebar icons."
                ) {
                    SidebarIconPicker(selection: sidebarIconColorModeBinding)
                }

                if projectStore.globalSettings.sidebarIconColorMode == .monochrome {
                    PropertyRow(
                        title: "Monochrome Style",
                        subtitle: "Accent on open folders shows the path you've expanded."
                    ) {
                        Picker("", selection: projectStore.globalSettingBinding(\.sidebarMonochromeVariant)) {
                            ForEach(SidebarMonochromeVariant.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                PropertyRow(
                    title: "Section Dock Icons",
                    subtitle: "The icons under each server's name, apart from the tree's."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.sidebarDockIconStyle)) {
                        ForEach(SidebarDockIconStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Toolbar Project Button",
                    subtitle: "Show your account avatar or the project icon in the toolbar."
                ) {
                    Picker("", selection: toolbarProjectButtonStyleBinding) {
                        ForEach(ToolbarProjectButtonStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            Section("Workspace") {
                PropertyRow(
                    title: "Animation Speed",
                    subtitle: "How fast panels, the rail and cards move. Reduce Motion in System Settings always wins."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.interfaceMotionSpeed)) {
                        ForEach(InterfaceMotionSpeed.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                PropertyRow(
                    title: "Spacing Between Panes",
                    subtitle: "Space between the server rail, the Explorer and the cards."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.workspaceGutter)) {
                        ForEach(WorkspaceGutter.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Card Corners",
                    subtitle: "Corner radius of the Explorer cards, the editor, results and other cards."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.workspaceCornerRadius)) {
                        ForEach(WorkspaceCornerRadius.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Server Rail Size",
                    subtitle: "Size of the server buttons in the rail."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.railItemSize)) {
                        ForEach(RailItemSize.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            Section("Theme") {
                PropertyRow(title: "Accent Color") {
                    Picker("", selection: accentColorSourceBinding) {
                        ForEach(AccentColorSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if projectStore.globalSettings.accentColorSource == .custom {
                    PropertyRow(title: "Color") {
                        AccentColorPalette(selection: customAccentColorHexBinding)
                    }
                }
            }

            Section("Editor") {
                PropertyRow(
                    title: "Outline Edge",
                    subtitle: "A strip on the editor's right edge marks statements and errors; click it to jump."
                ) {
                    Toggle("", isOn: projectStore.globalSettingBinding(\.editorOutlineEdge))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Statement Focus",
                    subtitle: "Shade the statement at the cursor and show a Run arrow beside it."
                ) {
                    Toggle("", isOn: projectStore.globalSettingBinding(\.editorStatementFocus))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Line Number Gutter",
                    subtitle: "Subtle shows numbers only; Column adds a faint full-height column; Lane adds a rounded, inset lane; Hairline adds only a thin edge."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.editorGutterStyle)) {
                        ForEach(EditorGutterStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                selectionCornersRow
            }

            editorFontSection

            Section {
                EditorFontPreview(
                    fontName: projectStore.globalSettings.defaultEditorFontFamily,
                    fontSize: projectStore.globalSettings.defaultEditorFontSize,
                    ligatures: projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

}
