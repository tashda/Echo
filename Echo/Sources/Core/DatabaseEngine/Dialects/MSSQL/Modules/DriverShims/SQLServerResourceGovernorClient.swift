import SQLServerKit
import Foundation
import NIO

/// Client for managing SQL Server Resource Governor.
public final class SQLServerResourceGovernorClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    // MARK: - Configuration
    
    /// Returns the current global configuration of the Resource Governor.
    public func fetchConfiguration() async throws -> SQLServerResourceGovernorConfiguration {
        let sql = "SELECT classifier_function_id, is_enabled, is_reconfiguration_pending FROM sys.resource_governor_configuration"
        let rows = try await client.query(sql)
        guard let row = rows.first else {
            throw NSError(domain: "dk.tippr.echo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resource Governor configuration not found."])
        }
        
        let classifierId = row.column("classifier_function_id")?.int ?? 0
        let isEnabled = row.column("is_enabled")?.int == 1
        let isPending = row.column("is_reconfiguration_pending")?.int == 1
        
        var classifierName: String? = nil
        if classifierId != 0 {
            let nameSql = "SELECT OBJECT_NAME(\(classifierId)) as name"
            classifierName = try await client.query(nameSql).first?.column("name")?.string
        }
        
        return SQLServerResourceGovernorConfiguration(
            isEnabled: isEnabled,
            classifierFunction: classifierName,
            isReconfigurationPending: isPending
        )
    }
    
    /// Enables the Resource Governor.
    public func enable() async throws {
        _ = try await client.query("ALTER RESOURCE GOVERNOR RECONFIGURE")
    }
    
    /// Disables the Resource Governor.
    public func disable() async throws {
        _ = try await client.query("ALTER RESOURCE GOVERNOR DISABLE")
    }
    
    /// Reconfigures the Resource Governor to apply pending changes.
    public func reconfigure() async throws {
        _ = try await client.query("ALTER RESOURCE GOVERNOR RECONFIGURE")
    }
    
    /// Sets the classifier function for the Resource Governor.
    public func setClassifierFunction(_ functionName: String?) async throws {
        let sql = if let name = functionName {
            "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = \(escapeIdentifier(name)))"
        } else {
            "ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL)"
        }
        _ = try await client.query(sql)
    }
    
    // MARK: - Resource Pools
    
    /// Lists all defined resource pools.
    public func listResourcePools(includeStats: Bool = false) async throws -> [SQLServerResourcePool] {
        let sql = """
        SELECT pool_id, name, min_cpu_percent, max_cpu_percent, min_memory_percent, max_memory_percent, cap_cpu_percent
        FROM sys.resource_governor_resource_pools
        """
        let rows = try await client.query(sql)
        
        var statsMap: [Int32: SQLServerResourcePool.Stats] = [:]
        if includeStats {
            let statsSql = """
            SELECT pool_id, active_session_count, used_memory_kb, target_memory_kb, cpu_usage_total
            FROM sys.dm_resource_governor_resource_pools
            """
            let statsRows = try await client.query(statsSql)
            for row in statsRows {
                if let id = row.column("pool_id")?.int32 {
                    statsMap[id] = SQLServerResourcePool.Stats(
                        activeSessionCount: row.column("active_session_count")?.int32 ?? 0,
                        usedMemoryKB: row.column("used_memory_kb")?.int64 ?? 0,
                        targetMemoryKB: row.column("target_memory_kb")?.int64 ?? 0,
                        cpuUsagePercent: row.column("cpu_usage_total")?.double ?? 0 // Note: This is an approximation
                    )
                }
            }
        }
        
        return rows.compactMap { row in
            guard let id = row.column("pool_id")?.int32,
                  let name = row.column("name")?.string else { return nil }
            
            return SQLServerResourcePool(
                poolId: id,
                name: name,
                minCpuPercent: row.column("min_cpu_percent")?.int32 ?? 0,
                maxCpuPercent: row.column("max_cpu_percent")?.int32 ?? 0,
                minMemoryPercent: row.column("min_memory_percent")?.int32 ?? 0,
                maxMemoryPercent: row.column("max_memory_percent")?.int32 ?? 0,
                capCpuPercent: row.column("cap_cpu_percent")?.int32 ?? 0,
                stats: statsMap[id]
            )
        }
    }
    
    // MARK: - Workload Groups
    
    /// Lists all defined workload groups.
    public func listWorkloadGroups(includeStats: Bool = false) async throws -> [SQLServerWorkloadGroup] {
        let sql = """
        SELECT g.group_id, g.name, p.name as pool_name, g.importance, 
               g.request_max_memory_grant_percent, g.request_max_cpu_time_sec,
               g.request_memory_grant_timeout_sec, g.max_dop, g.group_max_requests
        FROM sys.resource_governor_workload_groups g
        JOIN sys.resource_governor_resource_pools p ON g.pool_id = p.pool_id
        """
        let rows = try await client.query(sql)
        
        var statsMap: [Int32: SQLServerWorkloadGroup.Stats] = [:]
        if includeStats {
            let statsSql = """
            SELECT group_id, active_request_count, queued_request_count, blocked_task_count, total_cpu_usage_ms
            FROM sys.dm_resource_governor_workload_groups
            """
            let statsRows = try await client.query(statsSql)
            for row in statsRows {
                if let id = row.column("group_id")?.int32 {
                    statsMap[id] = SQLServerWorkloadGroup.Stats(
                        activeRequestCount: row.column("active_request_count")?.int32 ?? 0,
                        queuedRequestCount: row.column("queued_request_count")?.int32 ?? 0,
                        blockedTaskCount: row.column("blocked_task_count")?.int32 ?? 0,
                        totalCpuUsageMs: row.column("total_cpu_usage_ms")?.int64 ?? 0
                    )
                }
            }
        }
        
        return rows.compactMap { row in
            guard let id = row.column("group_id")?.int32,
                  let name = row.column("name")?.string,
                  let poolName = row.column("pool_name")?.string else { return nil }
            
            return SQLServerWorkloadGroup(
                groupId: id,
                name: name,
                poolName: poolName,
                importance: row.column("importance")?.string ?? "Medium",
                requestMaxMemoryGrantPercent: row.column("request_max_memory_grant_percent")?.int32 ?? 0,
                requestMaxCpuTimeSec: row.column("request_max_cpu_time_sec")?.int32 ?? 0,
                requestMemoryGrantTimeoutSec: row.column("request_memory_grant_timeout_sec")?.int32 ?? 0,
                maxDop: row.column("max_dop")?.int32 ?? 0,
                groupMaxRequests: row.column("group_max_requests")?.int32 ?? 0,
                stats: statsMap[id]
            )
        }
    }
    
    private func escapeIdentifier(_ identifier: String) -> String {
        "[\(identifier.replacingOccurrences(of: "]", with: "]]"))]"
    }
}
