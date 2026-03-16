import SwiftUI

// MARK: - Drop Position Types

enum DropPosition: Equatable {
    case beforeItem(UUID)
    case afterItem(UUID)
    case intoFolder(UUID)
    case atRootEnd
}

struct DropIndicator: Identifiable, Equatable {
    let id = UUID()
    let position: DropPosition
    let isActive: Bool
}

// MARK: - Drag Drop Delegate

@Observable
class DragDropDelegate {
    nonisolated(unsafe) static let shared = DragDropDelegate()

    var currentDropIndicator: DropIndicator?
    var expandedFoldersOnDrag: Set<UUID> = []

    @ObservationIgnored private var hoverTimer: Timer?
    @ObservationIgnored private let hoverDelay: TimeInterval = 0.8

    private init() {}

    func startDragHover(over folderId: UUID, expandedFolders: Set<UUID>) {
        // Cancel existing timer
        hoverTimer?.invalidate()

        // Don't expand if already expanded
        if expandedFolders.contains(folderId) {
            return
        }

        // Start new timer for expansion
        hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { _ in
            Task { @MainActor in
                DragDropDelegate.shared.expandedFoldersOnDrag.insert(folderId)
            }
        }
    }

    func endDragHover() {
        hoverTimer?.invalidate()
    }

    func setDropIndicator(_ indicator: DropIndicator?) {
        // Use a simple assignment with the assumption we're already on @MainActor
        currentDropIndicator = indicator
    }

    func clearDragState() {
        currentDropIndicator = nil
        expandedFoldersOnDrag.removeAll()
        hoverTimer?.invalidate()
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    let position: DropPosition
    let onDrop: (String) -> Bool
    @State private var isTargeted = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .overlay(
                Rectangle()
                    .fill(ColorTokens.accent)
                    .frame(height: 2)
                    .opacity(isTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)
            )
            .dropDestination(for: String.self) { items, location in
                let success = onDrop(items.first ?? "")
                return success
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isTargeted = targeted
                }
            }
    }
}
