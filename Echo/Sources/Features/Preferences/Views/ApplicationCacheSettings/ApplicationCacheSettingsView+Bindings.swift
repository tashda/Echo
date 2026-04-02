import SwiftUI

extension ApplicationCacheSettingsView {
    var resultCacheMaxBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultSpoolMaxBytes },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.resultSpoolMaxBytes = max(256 * 1_024 * 1_024, newValue)
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    await refreshResultCacheUsage()
                }
            }
        )
    }

    var resultCacheRetentionBinding: Binding<Int> {
        Binding(
            get: { projectStore.globalSettings.resultSpoolRetentionHours },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.resultSpoolRetentionHours = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var clipboardEnabledBinding: Binding<Bool> {
        Binding(
            get: { clipboardHistory.isEnabled },
            set: { newValue in
                if newValue {
                    clipboardHistory.setEnabled(true)
                } else {
                    confirmDisableHistory = true
                }
            }
        )
    }

    var clipboardStorageLimitBinding: Binding<Int> {
        Binding(
            get: { clipboardHistory.storageLimit },
            set: { clipboardHistory.updateStorageLimit($0) }
        )
    }
}
