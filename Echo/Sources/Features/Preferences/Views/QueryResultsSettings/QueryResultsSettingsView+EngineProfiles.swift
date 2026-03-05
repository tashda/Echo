import SwiftUI
import EchoSense

extension QueryResultsSettingsView {
    @ViewBuilder
    var engineSpecificSettings: some View {
        Group {
            switch selectedEngineTab {
            case .postgres:
                StreamingPresetPickerControl(
                    title: "Cursor threshold (LIMIT)",
                    value: cursorLimitThresholdBinding,
                    description: "LIMIT \u{2264} threshold \u{2192} simple streaming; larger/no LIMIT \u{2192} server\u{2011}side cursor.",
                    presets: streamingThresholdPresets,
                    range: 0...1_000_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.cursorLimitThreshold
                )
                StreamingPresetPickerControl(
                    title: "Cursor fetch size (baseline)",
                    value: backgroundFetchSizeBinding,
                    description: "Recommended \u{2265} 4,096 for large results.",
                    presets: streamingFetchPresets,
                    range: 128...16_384,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchSize
                )

            case .sqlserver:
                LabeledContent("Streaming mode") {
                    Picker("", selection: mssqlModeBinding) {
                        ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

            case .mysql:
                Text("MySQL streams results directly without explicit cursors or streaming modes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .sqlite:
                Text("SQLite runs in\u{2011}process — streaming and cursors do not apply.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
