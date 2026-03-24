import SQLServerKit
import Foundation

/// A policy in Policy-Based Management.
public struct SQLServerPolicy: Sendable, Equatable, Identifiable {
    public var id: Int32 { policyId }
    
    public let policyId: Int32
    public let name: String
    public let conditionName: String
    public let isEnabled: Bool
    public let executionMode: Int32
    public let scheduleName: String?
    public let helpLink: String?
    
    public init(policyId: Int32, name: String, conditionName: String, isEnabled: Bool, executionMode: Int32, scheduleName: String?, helpLink: String?) {
        self.policyId = policyId
        self.name = name
        self.conditionName = conditionName
        self.isEnabled = isEnabled
        self.executionMode = executionMode
        self.scheduleName = scheduleName
        self.helpLink = helpLink
    }
}

/// A condition in Policy-Based Management.
public struct SQLServerPolicyCondition: Sendable, Equatable, Identifiable {
    public var id: Int32 { conditionId }
    
    public let conditionId: Int32
    public let name: String
    public let facetName: String
    public let expression: String?
    
    public init(conditionId: Int32, name: String, facetName: String, expression: String?) {
        self.conditionId = conditionId
        self.name = name
        self.facetName = facetName
        self.expression = expression
    }
}

/// A management facet in Policy-Based Management.
public struct SQLServerPolicyFacet: Sendable, Equatable, Identifiable {
    public var id: String { name }
    
    public let name: String
    public let description: String?
    
    public init(name: String, description: String?) {
        self.name = name
        self.description = description
    }
}

/// Execution history for a policy.
public struct SQLServerPolicyHistory: Sendable, Equatable, Identifiable {
    public var id: Int64 { historyId }
    
    public let historyId: Int64
    public let policyId: Int32
    public let startDate: Date
    public let endDate: Date?
    public let result: Bool
    
    public init(historyId: Int64, policyId: Int32, startDate: Date, endDate: Date?, result: Bool) {
        self.historyId = historyId
        self.policyId = policyId
        self.startDate = startDate
        self.endDate = endDate
        self.result = result
    }
}
