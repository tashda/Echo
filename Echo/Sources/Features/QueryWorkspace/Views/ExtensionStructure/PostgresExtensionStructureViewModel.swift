import SwiftUI
import Combine

@MainActor
final class PostgresExtensionStructureViewModel: ObservableObject {
    let extensionName: String
    let databaseName: String
    let session: ConnectionSession
    
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var objects: [ExtensionObjectInfo] = []
    @Published var currentVersion: String?
    @Published var latestVersion: String?
    @Published var isUpdating = false
    @Published var homepageURL: String?
    @Published var documentationURL: String?
    @Published var description: String?
    
    var canUpdate: Bool {
        guard let current = currentVersion, let latest = latestVersion else { return false }
        return current != latest
    }
    
    init(extensionName: String, databaseName: String, session: ConnectionSession) {
        self.extensionName = extensionName
        self.databaseName = databaseName
        self.session = session
    }
    
    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            let dbSession = try await session.session.sessionForDatabase(databaseName)
            guard let metaSession = dbSession as? DatabaseMetadataSession else {
                throw DatabaseError.queryError("Metadata operations not supported")
            }
            
            async let fetches = (
                objs: dbSession.listExtensionObjects(extensionName: extensionName),
                installed: dbSession.listExtensions(),
                available: metaSession.listAvailableExtensions(),
                marketplace: PostgresMarketplace.shared.searchExtensions(query: extensionName)
            )
            
            let (objs, installed, available, marketplace) = try await (fetches.objs, fetches.installed, fetches.available, fetches.marketplace)
            let marketplaceEntry = marketplace.first { $0.name == extensionName }
            
            await MainActor.run {
                self.objects = objs
                self.currentVersion = installed.first(where: { $0.name == extensionName })?.comment?.replacingOccurrences(of: "Version: ", with: "")
                let serverAvailable = available.first(where: { $0.name == extensionName })
                self.latestVersion = serverAvailable?.defaultVersion
                self.description = serverAvailable?.comment ?? marketplaceEntry?.description
                self.homepageURL = marketplaceEntry?.homepage
                self.documentationURL = marketplaceEntry?.documentation
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func update() async {
        isUpdating = true
        do {
            let dbSession = try await session.session.sessionForDatabase(databaseName)
            guard let metaSession = dbSession as? DatabaseMetadataSession else {
                throw DatabaseError.queryError("Metadata operations not supported")
            }
            
            try await metaSession.updateExtension(name: extensionName, to: latestVersion)
            await reload()
        } catch {
            await MainActor.run {
                self.errorMessage = "Update failed: \(error.localizedDescription)"
                self.isUpdating = false
            }
        }
    }
    
    func estimatedMemoryUsageBytes() -> Int {
        // Objects array is small enough to not worry about fine-grained estimation
        return 64 * 1024
    }
}
