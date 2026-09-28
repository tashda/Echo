import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class PolicyManagementViewModel {
    var policies: [SQLServerPolicy] = []
    var conditions: [SQLServerPolicyCondition] = []
    var facets: [SQLServerPolicyFacet] = []
    var history: [SQLServerPolicyHistory] = []
    
    var isRefreshing = false
    var hasLoaded = false
    var loadErrorMessage: String?
    var selectedPolicyID: Int32?
    var selectedTab: PolicyTab = .policies
    
    enum PolicyTab: String, CaseIterable, Identifiable {
        case policies = "Policies"
        case conditions = "Conditions"
        case facets = "Facets"
        case history = "History"
        
        var id: String { rawValue }
    }
    
    @ObservationIgnored private let policyClient: SQLServerPolicyClient?
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored var activityEngine: ActivityEngine?
    private let logger = Logger(label: "PolicyManagementViewModel")

    init(policyClient: SQLServerPolicyClient?, connectionSessionID: UUID) {
        self.policyClient = policyClient
        self.connectionSessionID = connectionSessionID
    }

    func refresh() {
        guard let client = policyClient else {
            loadErrorMessage = "Policy-Based Management is not available for this connection."
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        loadErrorMessage = nil
        let handle = activityEngine?.begin(
            "Refreshing Policy Management",
            connectionSessionID: connectionSessionID
        )
        
        Task {
            do {
                async let p = client.listPolicies()
                async let c = client.listConditions()
                async let f = client.listFacets()
                async let h = client.fetchHistory(limit: 50)
                
                self.policies = try await p
                self.conditions = try await c
                self.facets = try await f
                self.history = try await h
                hasLoaded = true
                handle?.succeed()
            } catch {
                logger.error("Failed to load policy data: \(error)")
                loadErrorMessage = error.localizedDescription
                handle?.fail(error.localizedDescription)
            }
            isRefreshing = false
        }
    }

    var selectedPolicy: SQLServerPolicy? {
        policies.first { $0.policyId == selectedPolicyID }
    }

    func togglePolicy(name: String, currentlyEnabled: Bool) async {
        guard let client = policyClient else { return }
        let action = currentlyEnabled ? "Disabling" : "Enabling"
        let handle = activityEngine?.begin(
            "\(action) policy \(name)",
            connectionSessionID: connectionSessionID
        )
        do {
            if currentlyEnabled {
                try await client.disablePolicy(name: name)
            } else {
                try await client.enablePolicy(name: name)
            }
            handle?.succeed()
            refresh()
        } catch {
            logger.error("Failed to toggle policy '\(name)': \(error)")
            handle?.fail(error.localizedDescription)
            loadErrorMessage = error.localizedDescription
        }
    }

    func evaluatePolicy(name: String) async {
        guard let client = policyClient else { return }
        let handle = activityEngine?.begin(
            "Evaluating policy \(name)",
            connectionSessionID: connectionSessionID
        )
        do {
            try await client.evaluatePolicy(name: name)
            handle?.succeed()
            refresh()
        } catch {
            logger.error("Failed to evaluate policy '\(name)': \(error)")
            handle?.fail(error.localizedDescription)
            loadErrorMessage = error.localizedDescription
        }
    }
}
