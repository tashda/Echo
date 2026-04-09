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

            PropertyRow(title: "Object browser cache") {
                Picker("", selection: objectBrowserCacheMaxBinding) {
                    ForEach(Self.perTypeStorageOptions, id: \.bytes) { option in
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
