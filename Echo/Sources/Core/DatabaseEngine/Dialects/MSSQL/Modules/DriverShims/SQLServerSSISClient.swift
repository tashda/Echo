import SQLServerKit
import Foundation
import NIO

/// Client for interacting with the SQL Server Integration Services (SSIS) Catalog.
/// Provides access to folders, projects, packages, and execution history in SSISDB.
public final class SQLServerSSISClient: @unchecked Sendable {
    private let client: SQLServerClient
    
    internal init(client: SQLServerClient) {
        self.client = client
    }
    
    /// Checks if the SSISDB catalog is available on this instance.
    public func isSSISCatalogAvailable() async throws -> Bool {
        let sql = "SELECT ISNULL(DB_ID('SSISDB'), 0) AS is_available"
        let rows = try await client.query(sql)
        return (rows.first?.column("is_available")?.int ?? 0) > 0
    }
    
    /// Lists all folders in the SSIS Catalog.
    public func listFolders() async throws -> [SQLServerSSISFolder] {
        let sql = "SELECT folder_id, name, description, created_by_name, created_time FROM SSISDB.catalog.folders"
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("folder_id")?.int64,
                  let name = row.column("name")?.string,
                  let createdBy = row.column("created_by_name")?.string,
                  let createdTime = row.column("created_time")?.date else { return nil }
            return SQLServerSSISFolder(
                folderId: id,
                name: name,
                description: row.column("description")?.string,
                createdBy: createdBy,
                createdTime: createdTime
            )
        }
    }
    
    /// Lists all projects within a specific folder.
    public func listProjects(folderId: Int64) async throws -> [SQLServerSSISProject] {
        let sql = """
        SELECT project_id, folder_id, name, description, deployed_by_name, last_deployed_time 
        FROM SSISDB.catalog.projects 
        WHERE folder_id = \(folderId)
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("project_id")?.int64,
                  let fid = row.column("folder_id")?.int64,
                  let name = row.column("name")?.string,
                  let deployedBy = row.column("deployed_by_name")?.string,
                  let lastDeployed = row.column("last_deployed_time")?.date else { return nil }
            return SQLServerSSISProject(
                projectId: id,
                folderId: fid,
                name: name,
                description: row.column("description")?.string,
                deployedBy: deployedBy,
                lastDeployedTime: lastDeployed
            )
        }
    }
    
    /// Lists all packages within a specific project.
    public func listPackages(projectId: Int64) async throws -> [SQLServerSSISPackage] {
        let sql = """
        SELECT package_id, project_id, name, description, version_major, version_minor 
        FROM SSISDB.catalog.packages 
        WHERE project_id = \(projectId)
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("package_id")?.int64,
                  let pid = row.column("project_id")?.int64,
                  let name = row.column("name")?.string else { return nil }
            return SQLServerSSISPackage(
                packageId: id,
                projectId: pid,
                name: name,
                description: row.column("description")?.string,
                versionMajor: row.column("version_major")?.int32 ?? 0,
                versionMinor: row.column("version_minor")?.int32 ?? 0
            )
        }
    }
    
    /// Fetches recent execution history from the SSIS Catalog.
    public func fetchExecutions(limit: Int = 100) async throws -> [SQLServerSSISExecution] {
        let sql = """
        SELECT TOP (\(limit)) 
            execution_id, folder_name, project_name, package_name, 
            status, start_time, end_time, caller_name
        FROM SSISDB.catalog.executions
        ORDER BY start_time DESC
        """
        let rows = try await client.query(sql)
        return rows.compactMap { row in
            guard let id = row.column("execution_id")?.int64,
                  let folder = row.column("folder_name")?.string,
                  let project = row.column("project_name")?.string,
                  let package = row.column("package_name")?.string,
                  let status = row.column("status")?.int32,
                  let caller = row.column("caller_name")?.string else { return nil }
            return SQLServerSSISExecution(
                executionId: id,
                folderName: folder,
                projectName: project,
                packageName: package,
                status: status,
                startTime: row.column("start_time")?.date,
                endTime: row.column("end_time")?.date,
                callerName: caller
            )
        }
    }
}
