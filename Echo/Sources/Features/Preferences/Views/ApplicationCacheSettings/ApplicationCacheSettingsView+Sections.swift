import SwiftUI

extension ApplicationCacheSettingsView {

    var storageLimitsSection: some View {
        Section("Storage") {
            PropertyRow(title: "Maximum storage") {
                Picker("", selection: resultCacheMaxBinding) {
                    ForEach(Self.unifiedStorageOptions, id: \.bytes) { option in
                        Text(option.label).tag(option.bytes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
            }
        }
    }
}
