import SwiftUI

/// Settings › Appearance › Server Header as it would look at the chosen level, with the card above
/// it. Changing a row changes the round's controls, so everything else follows.
struct LabHCSettings: View {
    let values: RoundValues
    let server: LabSHServer

    var body: some View {
        let look = LabHCLook(values)
        VStack(spacing: SpacingTokens.none) {
            LabHCColumn { LabHCCard(server: server, look: look, rowLimit: 2) }
                .frame(height: SpacingTokens.xxxl * 4)
            Form {
                Section("Server Header") {
                    if look.level == .none {
                        Text("The colour and symbol are set per server. The header's type is Echo's.")
                            .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    if look.level.offers(.family) { picker("Typeface", "family", LabHCFamily.allCases, \.rawValue, \.short) }
                    if look.level.offers(.size) { picker("Size", "size", LabHCSize.allCases, \.rawValue, \.short) }
                    if look.level.offers(.weight) { picker("Weight", "weight", LabHCWeight.allCases, \.rawValue, \.short) }
                    if look.level.offers(.alignment) { picker("Alignment", "align", LabHCAlign.allCases, \.rawValue, \.short) }
                    if look.level.offers(.eyebrow) { picker("Line Above the Name", "eyebrow", LabHCEyebrow.allCases, \.rawValue, \.short) }
                    if look.level.offers(.density) { picker("Spacing", "density", LabHCDensity.allCases, \.rawValue, \.short) }
                }
                if look.level.offers(.edge) || look.level.offers(.fill) || look.level.offers(.textColour) {
                    Section("Banner") {
                        if look.level.offers(.fill) { picker("Fill", "fill", LabHCFill.allCases, \.rawValue, \.short) }
                        if look.level.offers(.edge) { picker("Edge", "edge", LabHCEdge.allCases, \.rawValue, \.short) }
                        if look.level.offers(.textColour) { picker("Text Color", "text", LabHCText.allCases, \.rawValue, \.short) }
                    }
                }
                if look.level.offers(.iconSize) {
                    Section("Icon Menu") { picker("Icon Size", "iconSize", LabHCIconSize.allCases, \.rawValue, \.short) }
                }
            }
            .formStyle(.grouped)
        }
        .background(ColorTokens.Workspace.canvas)
    }

    private func picker<E: Hashable>(_ title: String, _ id: String, _ cases: [E], _ raw: @escaping (E) -> String,
                                     _ short: @escaping (E) -> String) -> some View {
        Picker(title, selection: values.binding(id)) {
            ForEach(cases, id: \.self) { Text(short($0)).tag(raw($0)) }
        }
    }
}
