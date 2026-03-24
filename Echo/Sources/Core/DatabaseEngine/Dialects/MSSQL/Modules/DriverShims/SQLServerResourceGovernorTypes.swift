import SQLServerKit
import Foundation

/// Global configuration for the SQL Server Resource Governor.
public struct SQLServerResourceGovernorConfiguration: Sendable, Equatable {
    public let isEnabled: Bool
    public let classifierFunction: String?
    public let isReconfigurationPending: Bool
    
    public init(isEnabled: Bool, classifierFunction: String?, isReconfigurationPending: Bool) {
        self.isEnabled = isEnabled
        self.classifierFunction = classifierFunction
        self.isReconfigurationPending = isReconfigurationPending
    }
}

/// A resource pool in the Resource Governor.
public struct SQLServerResourcePool: Sendable, Equatable, Identifiable {
    public var id: Int32 { poolId }
    
    public let poolId: Int32
    public let name: String
    public let minCpuPercent: Int32
    public let maxCpuPercent: Int32
    public let minMemoryPercent: Int32
    public let maxMemoryPercent: Int32
    public let capCpuPercent: Int32
    
    /// Statistics from sys.dm_resource_governor_resource_pools
    public struct Stats: Sendable, Equatable {
        public let activeSessionCount: Int32
        public let usedMemoryKB: Int64
        public let targetMemoryKB: Int64
        public let cpuUsagePercent: Double
        
        public init(activeSessionCount: Int32, usedMemoryKB: Int64, targetMemoryKB: Int64, cpuUsagePercent: Double) {
            self.activeSessionCount = activeSessionCount
            self.usedMemoryKB = usedMemoryKB
            self.targetMemoryKB = targetMemoryKB
            self.cpuUsagePercent = cpuUsagePercent
        }
    }
    
    public var stats: Stats?
    
    public init(poolId: Int32, name: String, minCpuPercent: Int32, maxCpuPercent: Int32, minMemoryPercent: Int32, maxMemoryPercent: Int32, capCpuPercent: Int32, stats: Stats? = nil) {
        self.poolId = poolId
        self.name = name
        self.minCpuPercent = minCpuPercent
        self.maxCpuPercent = maxCpuPercent
        self.minMemoryPercent = minMemoryPercent
        self.maxMemoryPercent = maxMemoryPercent
        self.capCpuPercent = capCpuPercent
        self.stats = stats
    }
}

/// A workload group in the Resource Governor.
public struct SQLServerWorkloadGroup: Sendable, Equatable, Identifiable {
    public var id: Int32 { groupId }
    
    public let groupId: Int32
    public let name: String
    public let poolName: String
    public let importance: String
    public let requestMaxMemoryGrantPercent: Int32
    public let requestMaxCpuTimeSec: Int32
    public let requestMemoryGrantTimeoutSec: Int32
    public let maxDop: Int32
    public let groupMaxRequests: Int32
    
    /// Statistics from sys.dm_resource_governor_workload_groups
    public struct Stats: Sendable, Equatable {
        public let activeRequestCount: Int32
        public let queuedRequestCount: Int32
        public let blockedTaskCount: Int32
        public let totalCpuUsageMs: Int64
        
        public init(activeRequestCount: Int32, queuedRequestCount: Int32, blockedTaskCount: Int32, totalCpuUsageMs: Int64) {
            self.activeRequestCount = activeRequestCount
            self.queuedRequestCount = queuedRequestCount
            self.blockedTaskCount = blockedTaskCount
            self.totalCpuUsageMs = totalCpuUsageMs
        }
    }
    
    public var stats: Stats?
    
    public init(groupId: Int32, name: String, poolName: String, importance: String, requestMaxMemoryGrantPercent: Int32, requestMaxCpuTimeSec: Int32, requestMemoryGrantTimeoutSec: Int32, maxDop: Int32, groupMaxRequests: Int32, stats: Stats? = nil) {
        self.groupId = groupId
        self.name = name
        self.poolName = poolName
        self.importance = importance
        self.requestMaxMemoryGrantPercent = requestMaxMemoryGrantPercent
        self.requestMaxCpuTimeSec = requestMaxCpuTimeSec
        self.requestMemoryGrantTimeoutSec = requestMemoryGrantTimeoutSec
        self.maxDop = maxDop
        self.groupMaxRequests = groupMaxRequests
        self.stats = stats
    }
}
