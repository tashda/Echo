import SQLServerKit
import Foundation

// MARK: - SSIS Models

/// A folder in the SSIS Catalog.
public struct SQLServerSSISFolder: Sendable, Equatable, Identifiable {
    public var id: Int64 { folderId }
    public let folderId: Int64
    public let name: String
    public let description: String?
    public let createdBy: String
    public let createdTime: Date
}

/// A project in the SSIS Catalog.
public struct SQLServerSSISProject: Sendable, Equatable, Identifiable {
    public var id: Int64 { projectId }
    public let projectId: Int64
    public let folderId: Int64
    public let name: String
    public let description: String?
    public let deployedBy: String
    public let lastDeployedTime: Date
}

/// A package in an SSIS project.
public struct SQLServerSSISPackage: Sendable, Equatable, Identifiable {
    public var id: Int64 { packageId }
    public let packageId: Int64
    public let projectId: Int64
    public let name: String
    public let description: String?
    public let versionMajor: Int32
    public let versionMinor: Int32
}

/// An execution history record in the SSIS Catalog.
public struct SQLServerSSISExecution: Sendable, Equatable, Identifiable {
    public var id: Int64 { executionId }
    public let executionId: Int64
    public let folderName: String
    public let projectName: String
    public let packageName: String
    public let status: Int32 // 1=created, 2=running, 3=canceled, 4=failed, 5=pending, 6=ended unexpectedly, 7=succeeded, 8=stopping, 9=completed
    public let startTime: Date?
    public let endTime: Date?
    public let callerName: String
}
