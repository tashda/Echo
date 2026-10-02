import SwiftUI

/// What a user can change about the title banner header (round 53, LV2), in Settings › Appearance
/// under Server Header. One setting for every server card; the card in the Explorer is the preview.
struct ServerHeaderLookRows: View {
    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        PropertyRow(title: "Server Name Typeface", subtitle: "The typeface of the name on the banner.") {
            picker(\.serverHeaderLook.typeface, ServerHeaderTypeface.allCases, \.displayName)
        }
        PropertyRow(title: "Server Name Size", subtitle: "From Tiny (12pt) to Extra Large (26pt); Standard is 18pt.") {
            picker(\.serverHeaderLook.nameSize, ServerHeaderNameSize.allCases, \.displayName)
        }
        PropertyRow(
            title: "Line Above the Name",
            subtitle: "Small capitals naming the section or the engine, over the name or at its right. Nothing Above the Name leaves only the name."
        ) {
            picker(\.serverHeaderLook.eyebrow, ServerHeaderEyebrowLine.allCases, \.displayName)
        }
        PropertyRow(title: "Spacing", subtitle: "The room around the name: Tight is 6pt above it, Standard 10pt with more before the icons.") {
            picker(\.serverHeaderLook.spacing, ServerHeaderSpacing.allCases, \.displayName)
        }
        PropertyRow(title: "Banner Edge", subtitle: "How the colour ends against the card's rows.") {
            picker(\.serverHeaderLook.edge, ServerHeaderEdge.allCases, \.displayName)
        }
        PropertyRow(
            title: "Banner Text Color",
            subtitle: "Automatic uses dark type on light colors such as yellow and amber."
        ) {
            picker(\.serverHeaderLook.textColor, ServerHeaderTextColor.allCases, \.displayName)
        }
    }

    private func picker<Value: Hashable>(
        _ keyPath: WritableKeyPath<GlobalSettings, Value>,
        _ cases: [Value],
        _ title: KeyPath<Value, String>
    ) -> some View {
        Picker("", selection: projectStore.globalSettingBinding(keyPath)) {
            ForEach(cases, id: \.self) { Text($0[keyPath: title]).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
}
