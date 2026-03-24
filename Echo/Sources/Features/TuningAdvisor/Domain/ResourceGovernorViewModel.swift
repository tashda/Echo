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
    var isToggling = false
    var errorMessage: String?
    var selectedPoolID: Int32?
    var selectedGroupID: Int32?

    @ObservationIgnored private let rgClient: SQLServerResourceGovernorClient?
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored var activityEngine: ActivityEngine?
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
                configuration = try await client.fetchConfiguration()
                pools = try await client.listResourcePools(includeStats: true)
                groups = try await client.listWorkloadGroups(includeStats: true)
                isRefreshing = false
            } catch {
                logger.error("Failed to load Resource Governor data: \(error)")
                isRefreshing = false
            }
        }
    }

    func toggleEnabled() async {
        guard let client = rgClient, let config = configuration else { return }
        isToggling = true
        errorMessage = nil

        let action = config.isEnabled ? "Disabling" : "Enabling"
        let handle = activityEngine?.begin("\(action) Resource Governor", connectionSessionID: connectionSessionID)

        do {
            if config.isEnabled {
                try await client.disable()
            } else {
                try await client.enable()
            }
            try await client.reconfigure()
            handle?.succeed()
            isToggling = false
            refresh()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
            isToggling = false
        }
    }

    func reconfigure() async {
        guard let client = rgClient else { return }
        let handle = activityEngine?.begin("Reconfiguring Resource Governor", connectionSessionID: connectionSessionID)
        do {
            try await client.reconfigure()
            handle?.succeed()
            refresh()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    var selectedPool: SQLServerResourcePool? {
        pools.first { $0.poolId == selectedPoolID }
    }

    var selectedGroup: SQLServerWorkloadGroup? {
        groups.first { $0.groupId == selectedGroupID }
    }
}
