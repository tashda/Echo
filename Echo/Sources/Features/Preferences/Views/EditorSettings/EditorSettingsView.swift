import SwiftUI

/// Round 28.11 (SP0): every setting of the query editor in one pane, in the order you meet things
/// in the editor. Round 43: the template of a settings page, with a live editor pinned above that
/// follows every setting (PV1), pictures for the choices that change a look (CH1), a short line only
/// where the title isn't enough and the rest in ⓘ (DS1), a ↺ on a row that isn't the default (RS1)
/// and Reset This Page (RP0). Completion-only settings stay in EchoSense; result settings in Results.
struct EditorSettingsView: View {
    @Environment(ProjectStore.self) var projectStore

    var body: some View {
        SettingsPage(
            previewHeight: 190,
            resetPage: projectStore.resetPage(Self.resettable),
            preview: { EditorSettingsPreview(settings: projectStore.globalSettings) },
            sections: {
                textSection
                gutterSection
                typingSection
                marksSection
                runSection
                edgesSection
            }
        )
    }

    private var gutterSection: some View {
        Section("Gutter") {
            toggleRow("Line Numbers", \.editorShowLineNumbers)
            PropertyRow(
                title: "Style",
                info: "Also the row numbers of the results. Subtle shows numbers only; Column adds a faint full-height column; Lane a rounded, inset lane; Hairline only a thin edge.",
                resetAction: projectStore.resetAction(\.editorGutterStyle)
            ) {
                PictureChoicePicker(
                    selection: projectStore.globalSettingBinding(\.editorGutterStyle),
                    options: EditorGutterStyle.allCases,
                    title: \.displayName
                ) { EditorGutterPicture(style: $0) }
            }
        }
    }

    private var typingSection: some View {
        Section("While Typing") {
            toggleRow("Statement Focus", \.editorStatementFocus, subtitle: "With a Run arrow beside it")
            toggleRow("Highlight the Word at the Caret", \.editorHighlightSelectedSymbol)
            toggleRow("Check the Query as You Type", \.editorEnableLiveValidation,
                      info: EchoSenseInfoTopic.liveValidation.message)
            toggleRow("Wrap Long Lines", \.editorWrapLines)
        }
    }

    private var marksSection: some View {
        Section("Marks") {
            PropertyRow(
                title: "Corners",
                info: "Every mark on the text and the selection: the word at the caret, find, mistakes and replacements.",
                resetAction: projectStore.resetAction(\.editorMarkCorners)
            ) {
                PictureChoicePicker(
                    selection: projectStore.globalSettingBinding(\.editorMarkCorners),
                    options: EditorMarkCorners.allCases,
                    title: \.displayName,
                    pictureWidth: SpacingTokens.xl2
                ) { EditorMarkPicture(corners: $0, strength: projectStore.globalSettings.editorMarkStrength) }
            }
            PropertyRow(
                title: "Strength",
                info: "How strong every mark's tint is.",
                resetAction: projectStore.resetAction(\.editorMarkStrength)
            ) {
                PictureChoicePicker(
                    selection: projectStore.globalSettingBinding(\.editorMarkStrength),
                    options: EditorMarkStrength.allCases,
                    title: \.displayName
                ) { EditorMarkPicture(corners: projectStore.globalSettings.editorMarkCorners, strength: $0) }
            }
        }
    }

    private var runSection: some View {
        Section("After a Run") {
            toggleRow("Full Error Message at the Statement", \.editorErrorRunNoteShowsMessage,
                      info: "Off: a failed statement shows “! Error” where it ends, and the error's mark carries the message. On: the statement shows the message itself.")
        }
    }

    private var edgesSection: some View {
        Section("Edges") {
            toggleRow("Outline Edge", \.editorOutlineEdge, subtitle: "Statements and errors along the right edge",
                      info: "A strip on the editor's right edge marks statements and errors; click it to jump.")
        }
    }

    func toggleRow(_ title: String, _ keyPath: WritableKeyPath<GlobalSettings, Bool>,
                   subtitle: String? = nil, info: String? = nil) -> some View {
        PropertyRow(title: title, subtitle: subtitle, info: info, resetAction: projectStore.resetAction(keyPath)) {
            Toggle("", isOn: projectStore.globalSettingBinding(keyPath))
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    /// Everything Reset This Page puts back.
    static let resettable: [ResettableSetting] = [
        .init(\.defaultEditorFontFamily), .init(\.defaultEditorFontSize), .init(\.defaultEditorLineHeight),
        .init(\.fontLigatureOverrides), .init(\.editorShowLineNumbers), .init(\.editorGutterStyle),
        .init(\.editorStatementFocus), .init(\.editorHighlightSelectedSymbol), .init(\.editorEnableLiveValidation),
        .init(\.editorWrapLines), .init(\.editorMarkCorners), .init(\.editorMarkStrength),
        .init(\.editorErrorRunNoteShowsMessage), .init(\.editorOutlineEdge),
    ]
}
