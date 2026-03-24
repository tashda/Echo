import SQLServerKit
import Foundation
import NIO

/// Client for analyzing SQL Server object dependencies.
public final class SQLServerDependencyClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    /// Returns all scriptable objects in the current database.
    public func listAllObjects() async throws -> [SQLServerObjectIdentifier] {
        let sql = """
        SELECT SCHEMA_NAME(schema_id) as [schema], name, type
        FROM sys.objects
        WHERE is_ms_shipped = 0
          AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
        ORDER BY [schema], name
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let schema = row.column("schema")?.string,
                  let name = row.column("name")?.string,
                  let type = row.column("type")?.string else { return nil }
            return SQLServerObjectIdentifier(schema: schema, name: name, type: type.trimmingCharacters(in: .whitespaces))
        }
    }
    
    /// Fetches all cross-object dependencies in the current database.
    public func fetchDependencies() async throws -> [SQLServerObjectDependency] {
        let sql = """
        SELECT 
            SCHEMA_NAME(d.schema_id) as dep_schema, d.name as dep_name, d.type as dep_type,
            SCHEMA_NAME(r.schema_id) as ref_schema, r.name as ref_name, r.type as ref_type
        FROM sys.sql_expression_dependencies sed
        JOIN sys.objects d ON sed.referencing_id = d.object_id
        JOIN sys.objects r ON sed.referenced_id = r.object_id
        WHERE d.is_ms_shipped = 0 AND r.is_ms_shipped = 0
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let depSchema = row.column("dep_schema")?.string,
                  let depName = row.column("dep_name")?.string,
                  let depType = row.column("dep_type")?.string,
                  let refSchema = row.column("ref_schema")?.string,
                  let refName = row.column("ref_name")?.string,
                  let refType = row.column("ref_type")?.string else { return nil }
            
            return SQLServerObjectDependency(
                dependentObject: SQLServerObjectIdentifier(schema: depSchema, name: depName, type: depType.trimmingCharacters(in: .whitespaces)),
                referencedObject: SQLServerObjectIdentifier(schema: refSchema, name: refName, type: refType.trimmingCharacters(in: .whitespaces))
            )
        }
    }
    
    /// Builds a full dependency graph for the current database.
    public func buildGraph() async throws -> SQLServerDependencyGraph {
        async let objects = listAllObjects()
        async let dependencies = fetchDependencies()
        return try await SQLServerDependencyGraph(objects: objects, dependencies: dependencies)
    }
}
