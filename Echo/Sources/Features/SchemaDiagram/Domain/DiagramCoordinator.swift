import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class DiagramCoordinator: DiagramCoordinatorProtocol, @unchecked Sendable {
    internal let cacheManager: DiagramCacheStore
    internal let keyStore: DiagramEncryptionKeyStore
    internal let prefetchService = DiagramPrefetchService()
    private var refreshTask: Task<Void, Never>?
    
    var sessionProvider: (@MainActor @Sendable (UUID) -> (any DiagramSchemaProvider)?)?
    var globalSettingsProvider: (@MainActor @Sendable () -> GlobalSettings)?

    init(cacheManager: DiagramCacheStore, keyStore: DiagramEncryptionKeyStore) {
        self.cacheManager = cacheManager
        self.keyStore = keyStore
        
        Task {
            await prefetchService.setHandler { [weak self] request in
                await self?.handlePrefetchRequest(request) ?? false
            }
        }
    }

    func updateConfiguration(with settings: GlobalSettings) async {
        let rootDirectory = DiagramCacheStore.defaultRootDirectory()
        let normalizedLimit = max(settings.diagramCacheMaxBytes, 64 * 1_024 * 1_024)
        let configuration = DiagramCacheStore.Configuration(
            rootDirectory: rootDirectory,
            maximumBytes: UInt64(normalizedLimit)
        )
        await cacheManager.updateConfiguration(configuration)
    }

    func handleDiagramSettingsChange(_ settings: GlobalSettings) async {
        await prefetchService.cancelAll()
        await MainActor.run {
            restartDiagramRefreshTask(with: settings)
        }
    }

    private func restartDiagramRefreshTask(with settings: GlobalSettings) {
        refreshTask?.cancel()
        refreshTask = nil
        guard settings.diagramPrefetchMode == .full else { return }
        let cadence = settings.diagramRefreshCadence
        guard cadence != .never else { return }
        
        let intervalSeconds: TimeInterval = switch cadence {
            case .never: 0
            case .daily: 24 * 60 * 60
            case .weekly: 7 * 24 * 60 * 60
        }
        
        guard intervalSeconds > 0 else { return }
        let intervalNanoseconds = UInt64(intervalSeconds) * 1_000_000_000
        
        refreshTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                if Task.isCancelled { break }
            }
        }
    }

    func buildSchemaDiagram(for object: SchemaObjectInfo, projectID: UUID) async throws -> SchemaDiagramViewModel {
        throw NSError(domain: "DiagramCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use buildSchemaDiagram(for:session:...)"])
    }

    func queueDiagramPrefetch(for object: SchemaObjectInfo, relatedKeys: [DiagramTableKey], projectID: UUID) async {
        // Implementation provided in DiagramCoordinator+Prefetch.swift
    }

    @MainActor
    func refreshDiagram(for viewModel: SchemaDiagramViewModel) async {
        // EnvironmentState bridge for now until DiagramCoordinator has everything
    }
}
