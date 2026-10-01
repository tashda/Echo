import SwiftUI

extension ApplicationCacheSettingsView {
    var queryHistorySection: some View {
        Section {
            PropertyRow(title: "Keep query runs") {
                Picker("", selection: Binding(get: { appState.queryHistoryLimit }, set: { appState.queryHistoryLimit = $0 })) {
                    ForEach([500, 1_000, 5_000, 10_000], id: \.self) { Text($0.formatted()).tag($0) }
                }.labelsHidden().pickerStyle(.menu)
            }
            PropertyRow(title: "Query history retention") {
                Picker("", selection: Binding(get: { appState.queryHistoryRetentionHours }, set: { appState.queryHistoryRetentionHours = $0 })) {
                    ForEach(Self.retentionOptions, id: \.hours) { Text($0.label).tag($0.hours) }
                }.labelsHidden().pickerStyle(.menu)
            }
            PropertyRow(title: "Query History", subtitle: "\(appState.queryHistory.count.formatted()) runs · \(ByteCountFormatter.string(fromByteCount: Int64(appState.queryHistoryBytes), countStyle: .file))") {
                Button("Clear", role: .destructive) { appState.clearQueryHistory() }
                    .disabled(appState.queryHistory.isEmpty)
            }
        } header: {
            Text("Query History")
        } footer: {
            Text("Stores SQL and run details, separately from cached results. Both limits apply; Never clears and disables history. A connection can opt out in its settings.")
        }
    }
}
