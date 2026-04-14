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

    func refreshDiagramCacheUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingDiagramCache { return false }
            isRefreshingDiagramCache = true
            return true
        }
        guard shouldContinue else { return }
        let usage = await environmentState.diagramCacheStore.currentUsageBytes()
        await MainActor.run {
            diagramCacheUsage = usage
            isRefreshingDiagramCache = false
        }
    }

    func clearDiagramCache() {
        Task {
            await environmentState.diagramCacheStore.removeAll()
            await refreshDiagramCacheUsage()
        }
    }

    func refreshObjectBrowserCacheUsage() async {
        let shouldContinue = await MainActor.run { () -> Bool in
            if isRefreshingObjectBrowserCache { return false }
            isRefreshingObjectBrowserCache = true
            return true
        }
        guard shouldContinue else { return }
        let usage = await environmentState.objectBrowserCacheUsageBytes()
        await MainActor.run {
            objectBrowserCacheUsage = usage
            isRefreshingObjectBrowserCache = false
        }
    }

    func clearObjectBrowserCache() {
        Task {
            await environmentState.clearObjectBrowserCache()
            await refreshObjectBrowserCacheUsage()
        }
    }
}
