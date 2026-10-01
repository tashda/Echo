import SwiftUI

/// Round 28.11 (SP0): every setting of the query editor in one pane, in the order you meet things
/// in the editor. Completion-only settings stay in EchoSense; result settings stay in Results.
struct EditorSettingsView: View {
    @Environment(ProjectStore.self) var projectStore

    var body: some View {
        Form {
            textSection

            Section {
                EditorFontPreview(
                    fontName: projectStore.globalSettings.defaultEditorFontFamily,
                    fontSize: projectStore.globalSettings.defaultEditorFontSize,
                    ligatures: projectStore.globalSettings.ligaturesEnabled(for: projectStore.globalSettings.defaultEditorFontFamily)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Gutter") {
                toggleRow("Line Numbers", \.editorShowLineNumbers)
                PropertyRow(
                    title: "Style",
                    subtitle: "Subtle shows numbers only; Column adds a faint full-height column; Lane a rounded, inset lane; Hairline only a thin edge."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.editorGutterStyle)) {
                        ForEach(EditorGutterStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            Section("While Typing") {
                toggleRow("Statement Focus", \.editorStatementFocus,
                          subtitle: "Mark the statement at the cursor and show a Run arrow beside it.")
                toggleRow("Highlight the Word at the Caret", \.editorHighlightSelectedSymbol)
                toggleRow("Check the Query as You Type", \.editorEnableLiveValidation,
                          info: EchoSenseInfoTopic.liveValidation.message)
                toggleRow("Wrap Long Lines", \.editorWrapLines)
            }

            Section("Marks") {
                PropertyRow(title: "Corners", subtitle: "Every mark on the text and the selection: the word at the caret, find, mistakes and replacements.") {
                    Picker("", selection: projectStore.globalSettingBinding(\.editorMarkCorners)) {
                        ForEach(EditorMarkCorners.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                PropertyRow(title: "Strength", subtitle: "How strong every mark's tint is.") {
                    Picker("", selection: projectStore.globalSettingBinding(\.editorMarkStrength)) {
                        ForEach(EditorMarkStrength.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            Section("After a Run") {
                toggleRow("Full Error Message at the Statement", \.editorErrorRunNoteShowsMessage,
                          info: "Off: a failed statement shows “! Error” where it ends, and the error's mark carries the message. On: the statement shows the message itself.")
            }

            Section("Edges") {
                toggleRow("Outline Edge", \.editorOutlineEdge,
                          subtitle: "A strip on the editor's right edge marks statements and errors; click it to jump.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func toggleRow(_ title: String, _ keyPath: WritableKeyPath<GlobalSettings, Bool>,
                           subtitle: String? = nil, info: String? = nil) -> some View {
        PropertyRow(title: title, subtitle: subtitle, info: info) {
            Toggle("", isOn: projectStore.globalSettingBinding(keyPath))
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
