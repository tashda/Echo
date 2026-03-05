import SwiftUI
import EchoSense

extension ApplicationCacheSettingsView {
    func refreshResultCacheUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingResultCache { return false }
            isRefreshingResultCache = true
            return true
        }
        guard shouldContinue else { return }
        let bytes = await environmentState.resultSpoolManager.currentUsageBytes()
        await MainActor.run {
            self.resultCacheUsage = bytes
            self.isRefreshingResultCache = false
        }
    }

    func clearResultCache() {
        Task {
            await environmentState.resultSpoolManager.clearAll()
            await refreshResultCacheUsage()
        }
    }

    func clearAutocompleteHistory() {
        SQLAutoCompletionHistoryStore.shared.reset()
        autocompleteHistoryUsage = 0
    }

    func refreshAutocompleteHistoryUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingAutocompleteHistory { return false }
            isRefreshingAutocompleteHistory = true
            return true
        }
        guard shouldContinue else { return }

        let usage = SQLAutoCompletionHistoryStore.shared.currentUsageBytes()
        await MainActor.run {
            autocompleteHistoryUsage = usage
            isRefreshingAutocompleteHistory = false
        }
    }

    func clearClipboardHistory() {
        clipboardHistory.clearHistory()
    }
}
