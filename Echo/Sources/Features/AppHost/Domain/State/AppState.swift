import Foundation
import SwiftUI

/// Centralized application state management

@Observable final class AppState: @unchecked Sendable {
    struct StructureScriptPreviewData {
        let statements: [String]
    }

    /// Where the welcome is in leaving when a server connects (round 48, LV2 and CO1): the pills
    /// echo out first, then the server grows into the rail, then the tree slides out.
    enum WelcomeDeparture: Equatable {
        case idle
        /// The pills are leaving; the rail, the tree and the server page wait.
        case leaving
        /// The rail shows the server; the tree and the page follow.
        case railIn
    }

    // MARK: - UI State
    var welcomeDeparture: WelcomeDeparture = .idle
    var isLoading = false
    var currentError: DatabaseError?
    var showingError = false
    var activeSheet: ActiveSheet?
    var structureScriptData: StructureScriptPreviewData?
    /// The inspector column (round IC): whether it is out, and which of its four pages shows.
    /// The page is remembered while the column is closed and across launches.
    var isInspectorVisible = false
    var inspectorPage: InspectorPage = .details {
        didSet { historyDefaults.set(inspectorPage.rawValue, forKey: InspectorPage.defaultsKey) }
    }
    /// Details changed while another page showed (round IC, F1): the page strip marks Details.
    var hasUnseenDetails = false
    /// The Save card, while it shows (round IC, H1).
    var saveCardRequest: SaveCardRequest?
    /// A tab's Show in Bookmarks: the Bookmarks page selects and scrolls to it, then clears this.
    var revealedBookmarkID: UUID?
    /// The ⌘K palette (plan K4).
    var isCommandPaletteVisible = false {
        didSet {
            if !isCommandPaletteVisible { commandPaletteScope = .everything }
        }
    }
    /// What the palette lists: everything, or this window's tabs (the tab overview, round 35.1).
    var commandPaletteScope: CommandPaletteScope = .everything

    /// The server rail's opened trail (round 52): the + widens the pill into the saved connections.
    /// The rail animates the change itself, so the shortcut and the button both just set it.
    var isConnectTrailOpen = false

    /// The tab overview is the palette showing this window's tabs (round 35.1, TO6).
    var isTabOverviewVisible: Bool { isCommandPaletteVisible && commandPaletteScope == .tabs }

    /// ⇧⌘O, the toolbar button and a pinch: opens the palette on the tabs, or closes it.
    func toggleTabOverview() {
        if isTabOverviewVisible {
            isCommandPaletteVisible = false
        } else {
            commandPaletteScope = .tabs
            isCommandPaletteVisible = true
        }
    }
    /// Whether the Explorer tree shows beside the rail (⌃⌘S). The rail always shows.
    var isWorkspaceTreeVisible = true
    var workspaceTabBarStyle: WorkspaceTabBarStyle = .floating

    // MARK: - Query State
    var isQueryRunning = false
    var queryHistory: [QueryHistoryItem] = []
    var currentQuery = "SELECT NOW();"
    var sqlEditorTheme = SQLEditorTheme.fallback()
    var sqlEditorDisplay = SQLEditorDisplayOptions()

    // MARK: - Connection State
    var isConnecting = false
    var lastConnectionAttempt: Date?

    @ObservationIgnored private var errorDismissTask: Task<Void, Never>?

    @ObservationIgnored var historySaveTask: Task<Void, Never>?
    @ObservationIgnored let historyDefaults: UserDefaults

    init(historyDefaults: UserDefaults = .standard) {
        self.historyDefaults = historyDefaults
        inspectorPage = historyDefaults.string(forKey: InspectorPage.defaultsKey).flatMap(InspectorPage.init(rawValue:)) ?? .details
        loadQueryHistory()
    }

    // MARK: - Error Management

    func showError(_ error: DatabaseError) {
        currentError = error
        showingError = true
        isLoading = false
        isConnecting = false
        isQueryRunning = false
        scheduleErrorDismiss()
    }

    func clearError() {
        currentError = nil
        showingError = false
    }

    // MARK: - Loading States

    func startLoading() {
        isLoading = true
    }

    func stopLoading() {
        isLoading = false
    }

    // MARK: - Sheet Management

    func showSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }

    func showStructureScriptPreview(statements: [String]) {
        structureScriptData = StructureScriptPreviewData(statements: statements)
        activeSheet = .structureScriptPreview
    }

    func dismissSheet() {
        structureScriptData = nil
        activeSheet = nil
    }

    // MARK: - Private Methods

    private func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            clearError()
        }
    }


}

// MARK: - Supporting Types

enum ActiveSheet: String, Identifiable {
    case connectionEditor
    case quickConnect
    case preferences
    case about
    case exportData
    case structureScriptPreview

    var id: String {
        rawValue
    }
}
