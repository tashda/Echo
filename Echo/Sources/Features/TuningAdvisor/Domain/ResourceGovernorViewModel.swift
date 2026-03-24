import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class ResourceGovernorViewModel {
    var configuration: SQLServerResourceGovernorConfiguration?
    var pools: [SQLServerResourcePool] = []
    var groups: [SQLServerWorkloadGroup] = []
    
    var isRefreshing = false
    var selectedPoolID: Int32?
    var selectedGroupID: Int32?
    
    private let rgClient: SQLServerResourceGovernorClient?
    private let connectionSessionID: UUID
    private let logger = Logger(label: "ResourceGovernorViewModel")

    init(rgClient: SQLServerResourceGovernorClient?, connectionSessionID: UUID) {
        self.rgClient = rgClient
        self.connectionSessionID = connectionSessionID
    }

    func refresh() {
        guard let client = rgClient else { return }
        isRefreshing = true
        
        Task {
            do {
                async let c = client.fetchConfiguration()
                async let p = client.listResourcePools(includeStats: true)
                async let g = client.listWorkloadGroups(includeStats: true)
                
                self.configuration = try await c
                self.pools = try await p
                self.groups = try await g
                
                isRefreshing = false
            } catch {
                logger.error("Failed to load Resource Governor data: \(error)")
                isRefreshing = false
            }
        }
    }

    var selectedPool: SQLServerResourcePool? {
        pools.first { $0.poolId == selectedPoolID }
    }
    
    var selectedGroup: SQLServerWorkloadGroup? {
        groups.first { $0.groupId == selectedGroupID }
    }
}
