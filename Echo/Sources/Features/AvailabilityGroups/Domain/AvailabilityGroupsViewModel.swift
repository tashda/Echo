import Foundation
import SwiftUI
import SQLServerKit

/// View model for the Availability Groups dashboard, managing HADR data and failover actions.
@Observable
final class AvailabilityGroupsViewModel {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @ObservationIgnored private let agClient: SQLServerAvailabilityGroupsClient
    @ObservationIgnored let connectionSessionID: UUID

    var loadingState: LoadingState = .idle
    var isHadrEnabled = false
    var groups: [SQLServerAvailabilityGroup] = []
    var selectedGroupId: String?
    var replicas: [SQLServerAGReplica] = []
    var databases: [SQLServerAGDatabase] = []
    var detailLoadingState: LoadingState = .idle
    var showFailoverConfirmation = false
    var failoverGroupName: String?
    var isFailoverInProgress = false

    init(
        agClient: SQLServerAvailabilityGroupsClient,
        connectionSessionID: UUID
    ) {
        self.agClient = agClient
        self.connectionSessionID = connectionSessionID
    }

    var selectedGroup: SQLServerAvailabilityGroup? {
        guard let id = selectedGroupId else { return nil }
        return groups.first { $0.groupId == id }
    }

    func loadAll() async {
        loadingState = .loading
        do {
            isHadrEnabled = try await agClient.isHadrEnabled()
            if isHadrEnabled {
                groups = try await agClient.listGroups()
                if let first = groups.first, selectedGroupId == nil {
                    selectedGroupId = first.groupId
                    await loadGroupDetails(groupId: first.groupId)
                }
            }
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func selectGroup(_ groupId: String) async {
        selectedGroupId = groupId
        await loadGroupDetails(groupId: groupId)
    }

    func loadGroupDetails(groupId: String) async {
        detailLoadingState = .loading
        do {
            replicas = try await agClient.listReplicas(groupId: groupId)
            databases = try await agClient.listDatabases(groupId: groupId)
            detailLoadingState = .loaded
        } catch {
            detailLoadingState = .error(error.localizedDescription)
        }
    }

    func requestFailover(groupName: String) {
        failoverGroupName = groupName
        showFailoverConfirmation = true
    }

    func performFailover() async {
        guard let groupName = failoverGroupName else { return }
        isFailoverInProgress = true
        do {
            try await agClient.failover(groupName: groupName)
            showFailoverConfirmation = false
            failoverGroupName = nil
            await loadAll()
        } catch {
            loadingState = .error(error.localizedDescription)
        }
        isFailoverInProgress = false
    }

    func refresh() async {
        if let groupId = selectedGroupId {
            await loadGroupDetails(groupId: groupId)
        }
        await loadAll()
    }

    func setBackupPreference(groupName: String, preference: String) async {
        do {
            try await agClient.setBackupPreference(groupName: groupName, preference: preference)
            await loadAll()
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func removeDatabase(groupName: String, databaseName: String) async {
        do {
            try await agClient.removeDatabase(groupName: groupName, databaseName: databaseName)
            if let groupId = selectedGroupId {
                await loadGroupDetails(groupId: groupId)
            }
        } catch {
            detailLoadingState = .error(error.localizedDescription)
        }
    }

    func addDatabase(groupName: String, databaseName: String) async {
        do {
            try await agClient.addDatabase(groupName: groupName, databaseName: databaseName)
            if let groupId = selectedGroupId {
                await loadGroupDetails(groupId: groupId)
            }
        } catch {
            detailLoadingState = .error(error.localizedDescription)
        }
    }

    func estimatedMemoryUsageBytes() -> Int {
        let groupsSize = groups.count * 128
        let replicasSize = replicas.count * 256
        let databasesSize = databases.count * 256
        return 1024 * 64 + groupsSize + replicasSize + databasesSize
    }
}
