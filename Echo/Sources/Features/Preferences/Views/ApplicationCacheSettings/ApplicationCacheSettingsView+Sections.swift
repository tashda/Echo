import SwiftUI

extension ApplicationCacheSettingsView {

    var storageLimitsSection: some View {
        Section("Storage") {
            if !usePerTypeStorageLimits.wrappedValue {
                LabeledContent("Maximum storage") {
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

            Toggle("Set storage limits per cache type", isOn: usePerTypeStorageLimits)
                .toggleStyle(.switch)

            if usePerTypeStorageLimits.wrappedValue {
                LabeledContent("Result cache") {
                    Picker("", selection: resultCacheMaxBinding) {
                        ForEach(Self.perTypeStorageOptions, id: \.bytes) { option in
                            Text(option.label).tag(option.bytes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                }

                LabeledContent("Diagram cache") {
                    Picker("", selection: diagramCacheLimitBinding) {
                        ForEach(Self.perTypeStorageOptions, id: \.bytes) { option in
                            Text(option.label).tag(option.bytes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                }

                LabeledContent("EchoSense history") {
                    Picker("", selection: echoSenseStorageLimitBinding) {
                        ForEach(Self.perTypeStorageOptions, id: \.bytes) { option in
                            Text(option.label).tag(option.bytes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
                }

                if clipboardHistory.isEnabled {
                    LabeledContent("Clipboard history") {
                        Picker("", selection: clipboardStorageLimitBinding) {
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
    }
}
