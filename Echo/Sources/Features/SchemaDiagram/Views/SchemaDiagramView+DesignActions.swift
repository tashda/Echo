import SwiftUI

extension SchemaDiagramView {

    // MARK: - Refresh After Design Action

    func refreshAfterDesignAction() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await diagramBuilder.refreshDiagram(for: viewModel)
            isRefreshing = false
        }
    }
}
