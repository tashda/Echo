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
    var selectedPolicyID: Int32?
    var selectedTab: PolicyTab = .policies
    
    enum PolicyTab: String, CaseIterable, Identifiable {
        case policies = "Policies"
        case conditions = "Conditions"
        case facets = "Facets"
        case history = "History"
        
        var id: String { rawValue }
    }
    
    private let policyClient: SQLServerPolicyClient?
    private let connectionSessionID: UUID
    private let logger = Logger(label: "PolicyManagementViewModel")

    init(policyClient: SQLServerPolicyClient?, connectionSessionID: UUID) {
        self.policyClient = policyClient
        self.connectionSessionID = connectionSessionID
    }

    func refresh() {
        guard let client = policyClient else { return }
        isRefreshing = true
        
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
                
                isRefreshing = false
            } catch {
                logger.error("Failed to load policy data: \(error)")
                isRefreshing = false
            }
        }
    }

    var selectedPolicy: SQLServerPolicy? {
        policies.first { $0.policyId == selectedPolicyID }
    }
}
