import SQLServerKit
import Foundation
import NIO

/// Client for Policy-Based Management.
public final class SQLServerPolicyClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    // MARK: - Policies
    
    /// Lists all defined policies.
    public func listPolicies() async throws -> [SQLServerPolicy] {
        let sql = """
        SELECT p.policy_id, p.name, c.name as condition_name, p.is_enabled, 
               p.execution_mode, s.name as schedule_name, p.help_link
        FROM msdb.dbo.syspolicy_policies p
        JOIN msdb.dbo.syspolicy_conditions c ON p.condition_id = c.condition_id
        LEFT JOIN msdb.dbo.sysschedules s ON p.schedule_uid = s.schedule_uid
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("policy_id")?.int32,
                  let name = row.column("name")?.string,
                  let conditionName = row.column("condition_name")?.string else { return nil }
            
            return SQLServerPolicy(
                policyId: id,
                name: name,
                conditionName: conditionName,
                isEnabled: row.column("is_enabled")?.int == 1,
                executionMode: row.column("execution_mode")?.int32 ?? 0,
                scheduleName: row.column("schedule_name")?.string,
                helpLink: row.column("help_link")?.string
            )
        }
    }
    
    // MARK: - Conditions
    
    /// Lists all defined conditions.
    public func listConditions() async throws -> [SQLServerPolicyCondition] {
        let sql = """
        SELECT condition_id, name, facet_name, expression
        FROM msdb.dbo.syspolicy_conditions
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("condition_id")?.int32,
                  let name = row.column("name")?.string,
                  let facetName = row.column("facet_name")?.string else { return nil }
            
            return SQLServerPolicyCondition(
                conditionId: id,
                name: name,
                facetName: facetName,
                expression: row.column("expression")?.string
            )
        }
    }
    
    // MARK: - Facets
    
    /// Lists all available management facets.
    public func listFacets() async throws -> [SQLServerPolicyFacet] {
        let sql = "SELECT name, description FROM msdb.dbo.syspolicy_management_facets"
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let name = row.column("name")?.string else { return nil }
            return SQLServerPolicyFacet(name: name, description: row.column("description")?.string)
        }
    }
    
    // MARK: - History
    
    /// Returns the execution history for a specific policy.
    public func fetchHistory(policyId: Int32? = nil, limit: Int = 100) async throws -> [SQLServerPolicyHistory] {
        var sql = """
        SELECT TOP (\(limit)) history_id, policy_id, start_date, end_date, result
        FROM msdb.dbo.syspolicy_policy_execution_history
        """
        if let pid = policyId {
            sql += " WHERE policy_id = \(pid)"
        }
        sql += " ORDER BY start_date DESC"
        
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("history_id")?.int64,
                  let pid = row.column("policy_id")?.int32,
                  let startDate = row.column("start_date")?.date else { return nil }
            
            return SQLServerPolicyHistory(
                historyId: id,
                policyId: pid,
                startDate: startDate,
                endDate: row.column("end_date")?.date,
                result: row.column("result")?.int == 1
            )
        }
    }
    
    // MARK: - Execution
    
    /// Evaluates a policy manually.
    public func evaluatePolicy(name: String) async throws {
        // SQL Server evaluates policies via a complex internal engine or PowerShell.
        // We can trigger it via a stored procedure if available or by creating an on-demand job.
        // For now, we provide the T-SQL to check compliance if possible.
        throw NSError(domain: "dk.tippr.echo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Manual policy evaluation requires msdb internal procedures not yet implemented."])
    }
}
