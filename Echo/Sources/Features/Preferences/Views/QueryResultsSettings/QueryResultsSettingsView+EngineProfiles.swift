import SwiftUI
import EchoSense

extension QueryResultsSettingsView {
    @ViewBuilder
    var engineSpecificSettings: some View {
        Group {
            switch selectedEngineTab {
            case .postgres:
                StreamingModeRow(selection: streamingModeBinding)

                StreamingPresetPickerControl(
                    title: "Cursor Threshold",
                    value: cursorLimitThresholdBinding,
                    description: "LIMIT \u{2264} threshold \u{2192} simple streaming; larger/no LIMIT \u{2192} server\u{2011}side cursor.",
                    presets: streamingThresholdPresets,
                    range: 0...1_000_000,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.cursorLimitThreshold
                )
                StreamingPresetPickerControl(
                    title: "Cursor Fetch Size",
                    value: backgroundFetchSizeBinding,
                    description: "Recommended \u{2265} 4,096 for large results.",
                    presets: streamingFetchPresets,
                    range: 128...16_384,
                    formatter: formatRowCount,
                    defaultValue: ResultStreamingDefaults.fetchSize
                )

            case .sqlserver:
                StreamingModeRow(selection: mssqlModeBinding)

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

// MARK: - Streaming Mode Row

private struct StreamingModeRow: View {
    @Binding var selection: ResultStreamingExecutionMode
    @State private var isPopoverPresented = false

    private static let modeDescriptions: [(mode: ResultStreamingExecutionMode, summary: String)] = [
        (.auto, "Picks the best strategy per query"),
        (.simple, "Fetches all rows in one pass"),
        (.cursor, "Server-side cursor for large results"),
    ]

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Picker("", selection: $selection) {
                    ForEach(ResultStreamingExecutionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $isPopoverPresented,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(Self.modeDescriptions, id: \.mode) { item in
                            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                                Text(item.mode.displayName)
                                    .font(TypographyTokens.standard.weight(.semibold))
                                    .frame(width: 56, alignment: .leading)
                                Text(item.summary)
                                    .font(TypographyTokens.standard)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .frame(width: 320)
                }
            }
        } label: {
            Text("Streaming Mode")
        }
    }
}
