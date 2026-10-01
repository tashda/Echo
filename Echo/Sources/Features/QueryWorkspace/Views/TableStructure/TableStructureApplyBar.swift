import SwiftUI

/// The structure editor's pending changes (round 37.4, PR0): how many statements wait, Script,
/// Revert and Apply, at the bottom of its card. Apply reviews the statements first, as the
/// toolbar's Apply did before round 45 moved tool actions into the tab.
struct TableStructureApplyBar: View {
    let tab: WorkspaceTab
    @Bindable var viewModel: TableStructureEditorViewModel

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @State private var review: Review?

    private struct Review: Identifiable {
        let id = UUID()
        let tableName: String
        let statements: [String]
    }

    var body: some View {
        let statements = viewModel.generateStatements()
        ToolTabApplyBar(
            summary: ToolTabApplyBar.summary(count: statements.count),
            canApply: !statements.isEmpty,
            isApplying: viewModel.isApplying,
            extraTitle: "Script",
            onExtra: { if !statements.isEmpty { appState.showStructureScriptPreview(statements: statements) } },
            onRevert: { Task { await viewModel.reload() } },
            onApply: { if !statements.isEmpty { review = Review(tableName: viewModel.tableName, statements: statements) } }
        )
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .sheet(item: $review) { review in
            StructureApplyReviewSheet(tableName: review.tableName, statements: review.statements) {
                await applyChanges()
            }
        }
    }

    private func applyChanges() async -> Bool {
        await viewModel.applyChanges()
        if let error = viewModel.lastError {
            environmentState.notificationEngine?.post(category: .generalError, message: error)
            return false
        }
        guard viewModel.lastSuccessMessage != nil else { return false }
        environmentState.notificationEngine?.post(category: .generalSuccess, message: "Structure of \(viewModel.tableName) updated")
        await environmentState.refreshDatabaseStructure(
            for: tab.connectionSessionID,
            scope: .selectedDatabase,
            databaseOverride: tab.connection.database.isEmpty ? nil : tab.connection.database
        )
        return true
    }
}
