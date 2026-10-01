import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
internal struct TabOverviewDropDelegate: DropDelegate {
    let targetTabID: UUID?
    let isTrailingPlaceholder: Bool
    let tabStore: TabStore
    @Binding var draggingTabId: UUID?
    @Binding var dropTargetTabId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggingTabId != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTabId else { return }
        Task { @MainActor in
            if isTrailingPlaceholder {
                let count = tabStore.tabs.count
                guard count > 0 else { return }
                let destinationIndex = count - 1
                tabStore.moveTab(id: draggingID, to: destinationIndex)
                dropTargetTabId = nil
            } else if let targetID = targetTabID,
                      targetID != draggingID,
                      let targetIndex = tabStore.index(of: targetID) {
                tabStore.moveTab(id: draggingID, to: targetIndex)
                dropTargetTabId = targetID
            }
        }
    }

    func dropExited(info: DropInfo) {
        if isTrailingPlaceholder {
            dropTargetTabId = nil
        } else if dropTargetTabId == targetTabID {
            dropTargetTabId = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabId = nil
        dropTargetTabId = nil
        return true
    }
}
#endif
