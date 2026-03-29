import SwiftUI

extension SchemaDiagramView {

    // MARK: - Create Table

    func createTableFromDiagram() {
        showCreateTableSheet = true
    }

    // MARK: - Create Relationship

    func createRelationshipFromDiagram() {
        showCreateRelationshipSheet = true
    }

    // MARK: - Model Synchronization

    func synchronizeModelWithDatabase() {
        guard let context = viewModel.context,
              let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == context.connectionSessionID }) else {
            return
        }

        let tab = session.addSchemaDiffTab()
        if let schemaDiff = tab.schemaDiffVM {
            let resolved = SchemaDiffViewModel.resolvedSchemas(
                availableSchemas: schemaDiff.availableSchemas,
                preferredSource: context.object.schema,
                currentSource: context.object.schema,
                currentTarget: schemaDiff.targetSchema
            )
            schemaDiff.sourceSchema = resolved.source
            schemaDiff.targetSchema = resolved.target
            Task {
                await schemaDiff.compare()
            }
        }
    }

    // MARK: - Annotations

    func addAnnotationToDiagram() {
        let centerX = -contentOffset.width / zoom + viewSize.width / (2 * zoom)
        let centerY = -contentOffset.height / zoom + viewSize.height / (2 * zoom)
        viewModel.addAnnotation(at: CGPoint(x: centerX, y: centerY))
    }

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
