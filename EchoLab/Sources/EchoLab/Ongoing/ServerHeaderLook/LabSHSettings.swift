import SwiftUI

/// Settings › Appearance as rev 2 of round 30.1 proposes it: the rows Echo has today (Sidebar Icons,
/// Section Dock Icons), then Current Dock Icon beside them, and Server Header and Server Header
/// Colour. Header colour and dock icon change the round's controls; Server Header switches the
/// card below between Plain (HD0) and the header chosen in the round.
struct LabSHSettings: View {
    let values: RoundValues
    @State private var isPlain = false
    @State private var sidebarIcons = "Duotone"
    @State private var dockIcons = "Mono"

    var body: some View {
        let chosen = LabSHLook(values)
        let server = (LabSHSample(rawValue: values["sample"]) ?? .production).server
        VStack(spacing: SpacingTokens.none) {
            Form {
                Section {
                    menu("Sidebar Icons", "Choose your preferred look for sidebar icons.", $sidebarIcons, ["Duotone", "Mono"])
                    menu("Section Dock Icons", "The icons under each server's name, apart from the tree's.", $dockIcons, ["Mono", "Duotone"])
                    Picker(selection: values.binding("dockTint")) {
                        ForEach(LabSHDockTint.allCases, id: \.self) { Text($0.settingName).tag($0.rawValue) }
                    } label: {
                        label("Current Dock Icon", "The section you are in. Header's Colour falls back to the accent when the header has none.")
                    }
                }
                Section("Server Header") {
                    Picker(selection: $isPlain) {
                        Text("Plain").tag(true)
                        Text(chosen.style == .today ? "Coloured" : "Coloured (\(chosen.style.number))").tag(false)
                    } label: {
                        label("Style", "Plain is today's name and product line.")
                    }
                    .pickerStyle(.segmented)
                    Picker(selection: values.binding("source")) {
                        ForEach(LabSHColourSource.allCases, id: \.self) { Text($0.settingName).tag($0.rawValue) }
                    } label: {
                        label("Colour", "The server's colour is set in Manage Connections or from the header's menu.")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            LabSHColumn {
                LabSHCard(server: server, look: isPlain ? chosen.with(.today) : chosen, rowLimit: 2)
            }
        }
    }

    private func menu(_ title: String, _ subtitle: String, _ selection: Binding<String>, _ options: [String]) -> some View {
        Picker(selection: selection) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        } label: {
            label(title, subtitle)
        }
    }

    private func label(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(title)
            Text(subtitle).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
