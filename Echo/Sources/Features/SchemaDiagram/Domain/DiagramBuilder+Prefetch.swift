import Foundation
import SwiftUI

extension DiagramBuilder {
    
    @MainActor
    func handlePrefetchRequest(_ request: DiagramPrefetcher.Request) async -> Bool {
        let settings = globalSettingsProvider?() ?? GlobalSettings()
        guard settings.diagramPrefetchMode != .off else { return false }
        
        if let _ = try? await cacheManager.payload(for: request.cacheKey) {
            return true
        }
        
        guard let session = sessionProvider?(request.connectionSessionID) else {
            return false
        }
        
        do {
            _ = try await buildSchemaDiagram(
                for: request.object,
                session: session,
                projectID: request.cacheKey.projectID,
                cacheKey: request.cacheKey,
                progress: nil,
                isPrefetch: true
            )
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func persistDiagramLayout(for viewModel: SchemaDiagramViewModel) async {
        guard let snapshot = viewModel.cachedStructure,
              let checksum = viewModel.cachedChecksum else { return }
        
        let cacheKey = DiagramCacheKey(
            projectID: UUID(), // Fallback
            connectionID: UUID(), // Fallback
            schema: viewModel.nodes.first?.schema ?? "",
            table: viewModel.nodes.first?.name ?? ""
        )
        
        let payload = DiagramCachePayload(
            key: cacheKey,
            checksum: checksum,
            structure: snapshot,
            layout: viewModel.layoutSnapshot(),
            loadingSummary: nil
        )
        
        try? await cacheManager.stashPayload(payload)
    }

    @MainActor
    func scheduleRelatedPrefetch(
        session: any DiagramSchemaProvider,
        baseKey: DiagramTableKey,
        relatedKeys: [DiagramTableKey],
        projectID: UUID
    ) async {
        let settings = globalSettingsProvider?() ?? GlobalSettings()
        guard settings.diagramPrefetchMode != .off else { return }
        
        let filteredKeys = relatedKeys.filter { $0 != baseKey }
        guard !filteredKeys.isEmpty else { return }
        
        let sortedKeys = filteredKeys.sorted {
            if $0.schema.caseInsensitiveCompare($1.schema) == .orderedSame {
                return $0.name.lowercased() < $1.name.lowercased()
            }
            return $0.schema.lowercased() < $1.schema.lowercased()
        }
        
        let keysToQueue: [DiagramTableKey] = switch settings.diagramPrefetchMode {
            case .off: []
            case .recentlyOpened: Array(sortedKeys.prefix(8))
            case .full: sortedKeys
        }
        
        for key in keysToQueue {
            let cacheKey = DiagramCacheKey(
                projectID: projectID,
                connectionID: session.connectionID,
                schema: key.schema,
                table: key.name
            )
            let object = SchemaObjectInfo(name: key.name, schema: key.schema, type: .table)
            let request = DiagramPrefetcher.Request(
                cacheKey: cacheKey,
                connectionSessionID: session.connectionID,
                object: object,
                isBackgroundSweep: false
            )
            await prefetchService.enqueue(request, prioritize: true)
        }
    }
}
