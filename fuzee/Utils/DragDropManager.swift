import SwiftUI
import Combine

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

// MARK: - Drag Drop Manager

@MainActor
class DragDropManager: ObservableObject {
    static let shared = DragDropManager()

    @Published var currentDropIndicator: DropIndicator?
    @Published var expandedFoldersOnDrag: Set<UUID> = []

    private var hoverTimer: Timer?
    private let hoverDelay: TimeInterval = 0.8

    private init() {}

    func startDragHover(over folderId: UUID, expandedFolders: Set<UUID>) {
        // Cancel existing timer
        hoverTimer?.invalidate()

        // Don't expand if already expanded
        if expandedFolders.contains(folderId) {
            return
        }

        // Start new timer for expansion
        hoverTimer = Timer.scheduledTimer(withTimeInterval: hoverDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.expandedFoldersOnDrag.insert(folderId)
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
                    .fill(Color.accentColor)
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