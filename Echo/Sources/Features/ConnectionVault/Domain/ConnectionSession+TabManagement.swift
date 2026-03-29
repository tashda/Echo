import Foundation
import SwiftUI

// MARK: - Tab Management

extension ConnectionSession {

    func closeQueryTab(withID tabID: UUID) {
        guard let index = queryTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = queryTabs[index]

        // Proactively cancel any executing query task for this tab before removal
        if let state = tab.query {
            state.cancelExecution()
        }

        // Stop activity monitor streaming if this is an activity monitor tab
        if let activityVM = tab.activityMonitor {
            activityVM.stopStreaming()
        }

        if tab.ownsSession {
            Task {
                await tab.session.close()
            }
        }

        queryTabs.remove(at: index)

        // Adjust active tab
        if activeQueryTabID == tabID {
            if !queryTabs.isEmpty {
                // Select the previous tab, or the first one if we removed the first
                let newIndex = max(0, index - 1)
                activeQueryTabID = queryTabs.indices.contains(newIndex) ? queryTabs[newIndex].id : queryTabs.first?.id
            } else {
                activeQueryTabID = nil
            }
        }
        lastActivity = Date()
    }

    func updateActivity() {
        lastActivity = Date()
    }

    func updateDefaultInitialBatchSize(_ batchSize: Int) {
        defaultInitialBatchSize = max(100, batchSize)
    }

    func updateDefaultBackgroundStreamingThreshold(_ threshold: Int) {
        defaultBackgroundStreamingThreshold = max(100, threshold)
    }

    func updateDefaultBackgroundFetchSize(_ fetchSize: Int) {
        defaultBackgroundFetchSize = max(128, min(fetchSize, 16_384))
    }
}
