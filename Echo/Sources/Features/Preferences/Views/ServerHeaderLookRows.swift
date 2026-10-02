import SwiftUI

/// What a user can change about the title banner header (round 53, LV2), in Settings › Appearance
/// under Server Header. One setting for every server card; the card in the Explorer is the preview.
struct ServerHeaderLookRows: View {
    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        PropertyRow(title: "Server Name Typeface", subtitle: "The typeface of the name on the banner.") {
            picker(\.serverHeaderLook.typeface, ServerHeaderTypeface.allCases, \.displayName)
        }
        PropertyRow(title: "Server Name Size", subtitle: "Small is 18pt, Medium 22pt and Large 26pt.") {
            picker(\.serverHeaderLook.nameSize, ServerHeaderNameSize.allCases, \.displayName)
        }
        PropertyRow(
            title: "Line Above the Name",
            subtitle: "Small capitals over the name. A closed card shows the engine instead of the section."
        ) {
            picker(\.serverHeaderLook.eyebrow, ServerHeaderEyebrowLine.allCases, \.displayName)
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
