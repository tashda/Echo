import Foundation
import SwiftUI

/// Centralized application state management

@Observable final class AppState: @unchecked Sendable {
    struct StructureScriptPreviewData {
        let statements: [String]
    }

    // MARK: - UI State
    var isLoading = false
    var currentError: DatabaseError?
    var showingError = false
    var activeSheet: ActiveSheet?
    var structureScriptData: StructureScriptPreviewData?
    /// The notification history, in the inspector's column (plan N3, round 15 option B). While
    /// it shows, the column shows it instead of the details.
    var isNotificationHistoryVisible = false
    /// Round 39: saved SQL lives beside the tab, independently of the Explorer tree.
    var workspaceLibrary: WorkspaceLibrarySection?
    /// The ⌘K palette (plan K4).
    var isCommandPaletteVisible = false {
        didSet {
            if !isCommandPaletteVisible { commandPaletteScope = .everything }
        }
    }
    /// What the palette lists: everything, or this window's tabs (the tab overview, round 35.1).
    var commandPaletteScope: CommandPaletteScope = .everything

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
    /// The inspector's details. Showing them puts the notification history away, so any request
    /// for details (a double-click, JSON, a cell) lands on the details.
    var showInfoSidebar = false {
        didSet {
            if showInfoSidebar { isNotificationHistoryVisible = false; workspaceLibrary = nil }
        }
    }

    /// Whether the trailing column is out, for the details or the history.
    var isInspectorColumnVisible: Bool { showInfoSidebar || isNotificationHistoryVisible || workspaceLibrary != nil }

    /// The bell: shows the history in the column, or, if it is showing, closes the column. The
    /// column holds one thing at a time, so closing it never falls back to the details.
    func toggleNotificationHistory() {
        if isNotificationHistoryVisible {
            isNotificationHistoryVisible = false
        } else {
            showNotificationHistory()
        }
    }

    /// Shows the history in the column in place of the details.
    func showNotificationHistory() {
        showInfoSidebar = false
        workspaceLibrary = nil
        isNotificationHistoryVisible = true
    }

    /// The inspector button and ⌥⌘I: from the history they switch to the details, otherwise they
    /// show or hide the column.
    func toggleInspector() {
        if isNotificationHistoryVisible || workspaceLibrary != nil {
            isNotificationHistoryVisible = false
            workspaceLibrary = nil
            showInfoSidebar = true
        } else {
            showInfoSidebar.toggle()
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
