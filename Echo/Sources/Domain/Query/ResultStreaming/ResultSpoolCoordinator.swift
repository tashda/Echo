import Foundation
import Observation

@Observable
final class ResultSpoolCoordinator: ResultSpoolCoordinatorProtocol, @unchecked Sendable {
    private let spoolManager: ResultSpoolManager

    init(spoolManager: ResultSpoolManager) {
        self.spoolManager = spoolManager
    }

    func updateConfiguration(with settings: GlobalSettings) async {
        let path = settings.resultSpoolCustomLocation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rootDirectory: URL
        if let path = path, !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            rootDirectory = URL(fileURLWithPath: expanded, isDirectory: true)
        } else {
            rootDirectory = ResultSpoolManager.defaultRootDirectory()
        }

        let normalizedLimit = max(settings.resultSpoolMaxBytes, 256 * 1_024 * 1_024)
        let normalizedRetention = max(settings.resultSpoolRetentionHours, 1)
        let config = ResultSpoolConfiguration(
            rootDirectory: rootDirectory,
            maximumBytes: UInt64(normalizedLimit),
            retentionInterval: TimeInterval(normalizedRetention) * 3600,
            inMemoryRowLimit: max(settings.resultsInitialRowLimit, 100)
        )

        await spoolManager.update(configuration: config)
    }

    func makeSpoolHandle() async throws -> ResultSpoolHandle {
        try await spoolManager.makeSpoolHandle()
    }

    func removeSpool(for id: UUID) async {
        await spoolManager.removeSpool(for: id)
    }
}
