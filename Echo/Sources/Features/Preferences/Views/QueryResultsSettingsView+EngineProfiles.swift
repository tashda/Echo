import SwiftUI
import EchoSense

extension QueryResultsSettingsView {
    @ViewBuilder
    var engineSpecificSettings: some View {
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
            Text("These options apply to PostgreSQL only.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .sqlserver:
            LabeledContent("Streaming mode (SQL Server)") {
                Picker("", selection: mssqlModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("SQL Server uses SELECT TOP/FETCH NEXT; LIMIT threshold does not apply.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .mysql:
            LabeledContent("Streaming mode (MySQL)") {
                Picker("", selection: mysqlModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("MySQL streams results without explicit cursors.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .sqlite:
            LabeledContent("Streaming mode (SQLite)") {
                Picker("", selection: sqliteModeBinding) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            Text("SQLite is in\u{2011}process; streaming/cursors don\u{2019}t apply.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
