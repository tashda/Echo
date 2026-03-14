import SwiftUI
import Combine

@MainActor
final class PostgresExtensionsManagerViewModel: ObservableObject {
    let databaseName: String
    let session: ConnectionSession
    
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    @Published var installedExtensions: [SchemaObjectInfo] = []
    @Published var availableOnServer: [AvailableExtensionInfo] = []
    @Published var marketplaceExtensions: [CommunityExtension] = []
    
    @Published var selectedTab: Tab = .installed
    @Published var searchText: String = ""
    @Published var isSuperuser: Bool = false
    @Published var hasTLE: Bool = false
    
    @Published var isPerformingAction: Bool = false
    
    enum Tab: String, CaseIterable {
        case installed = "Installed"
        case marketplace = "Marketplace"
    }
    
    var filteredInstalled: [SchemaObjectInfo] {
        if searchText.isEmpty { return installedExtensions }
        return installedExtensions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredAvailable: [AvailableExtensionInfo] {
        if searchText.isEmpty { return availableOnServer }
        return availableOnServer.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.comment?.localizedCaseInsensitiveContains(searchText) ?? false) }
    }
    
    var filteredMarketplace: [CommunityExtension] {
        if searchText.isEmpty { return marketplaceExtensions }
        return marketplaceExtensions.filter { $0.name.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) }
    }
    
    init(databaseName: String, session: ConnectionSession) {
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
            
            async let installed = dbSession.listExtensions()
            async let available = metaSession.listAvailableExtensions()
            async let superUser = dbSession.isSuperuser()
            async let marketplace = PostgresMarketplaceService.shared.searchExtensions(query: "")
            
            let (inst, avail, isSuper, market) = try await (installed, available, superUser, marketplace)
            
            await MainActor.run {
                self.installedExtensions = inst
                self.availableOnServer = avail
                self.isSuperuser = isSuper
                self.marketplaceExtensions = market
                self.hasTLE = avail.contains(where: { $0.name == "pg_tle" })
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func installExtension(_ name: String, schema: String = "public", cascade: Bool = false) async {
        isPerformingAction = true
        do {
            let dbSession = try await session.session.sessionForDatabase(databaseName)
            guard let metaSession = dbSession as? DatabaseMetadataSession else { return }
            
            try await metaSession.installExtension(name: name, schema: schema, version: nil, cascade: cascade)
            await reload()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to install: \(error.localizedDescription)"
                self.isPerformingAction = false
            }
        }
        isPerformingAction = false
    }
    
    func dropExtension(_ name: String, cascade: Bool = false) async {
        isPerformingAction = true
        do {
            let dbSession = try await session.session.sessionForDatabase(databaseName)
            // PostgresWire driver update was pushed earlier
            _ = try await dbSession.simpleQuery("DROP EXTENSION IF EXISTS \"\(name)\"\(cascade ? " CASCADE" : "");")
            await reload()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to drop: \(error.localizedDescription)"
                self.isPerformingAction = false
            }
        }
        isPerformingAction = false
    }
    
    func estimatedMemoryUsageBytes() -> Int {
        return 128 * 1024
    }
}
