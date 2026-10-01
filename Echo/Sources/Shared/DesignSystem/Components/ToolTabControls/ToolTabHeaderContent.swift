import SwiftUI

/// What a tool puts in its tab's one header line (round 37.2, UH5): its controls at the right,
/// and a detail after the server ("14 policies"). The tool sets them from inside its content;
/// the tab's header (`ToolTabContainer`) draws them.
struct ToolTabHeaderContent {
    var controls: AnyView?
    var detail: String?
}

struct ToolTabHeaderContentKey: PreferenceKey {
    static var defaultValue: ToolTabHeaderContent { ToolTabHeaderContent() }

    static func reduce(value: inout ToolTabHeaderContent, nextValue: () -> ToolTabHeaderContent) {
        let next = nextValue()
        if value.controls == nil { value.controls = next.controls }
        if value.detail == nil { value.detail = next.detail }
    }
}

extension View {
    /// The tool's controls for its header line: the picker, search, other actions and the main
    /// action, in that order (round 37.2 and 37.3).
    /// The innermost view that sets them wins, so a page can replace its tool's controls.
    func toolTabHeaderControls<Controls: View>(@ViewBuilder _ controls: () -> Controls) -> some View {
        let view = AnyView(controls())
        return transformPreference(ToolTabHeaderContentKey.self) { value in
            if value.controls == nil { value.controls = view }
        }
    }

    /// A detail after the server in the tool's header ("14 policies").
    func toolTabHeaderDetail(_ detail: String?) -> some View {
        transformPreference(ToolTabHeaderContentKey.self) { value in
            if value.detail == nil { value.detail = detail }
        }
    }
}
