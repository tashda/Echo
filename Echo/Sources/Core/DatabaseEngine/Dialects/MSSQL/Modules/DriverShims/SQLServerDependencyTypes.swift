import SQLServerKit
import Foundation

/// Uniquely identifies a SQL Server object for dependency tracking.
public struct SQLServerObjectIdentifier: Sendable, Equatable, Hashable {
    public let schema: String
    public let name: String
    public let type: String // e.g., 'U', 'V', 'P', 'FN'
    
    public init(schema: String, name: String, type: String) {
        self.schema = schema
        self.name = name
        self.type = type
    }
    
    public var qualifiedName: String {
        "[\(schema)].[\(name)]"
    }
}

/// Represents a dependency relationship between two SQL Server objects.
public struct SQLServerObjectDependency: Sendable, Equatable {
    /// The object that depends on another.
    public let dependentObject: SQLServerObjectIdentifier
    /// The object being referenced.
    public let referencedObject: SQLServerObjectIdentifier
    
    public init(dependentObject: SQLServerObjectIdentifier, referencedObject: SQLServerObjectIdentifier) {
        self.dependentObject = dependentObject
        self.referencedObject = referencedObject
    }
}

/// A collection of objects and their dependencies, ready for topological sorting.
public struct SQLServerDependencyGraph: Sendable {
    public let objects: [SQLServerObjectIdentifier]
    public let dependencies: [SQLServerObjectDependency]
    
    public init(objects: [SQLServerObjectIdentifier], dependencies: [SQLServerObjectDependency]) {
        self.objects = objects
        self.dependencies = dependencies
    }
    
    /// Returns the objects in an order safe for scripting (topological sort).
    /// Objects with no dependencies come first.
    public func resolvedOrder() -> [SQLServerObjectIdentifier] {
        var result: [SQLServerObjectIdentifier] = []
        var visited = Set<SQLServerObjectIdentifier>()
        var currentlyVisiting = Set<SQLServerObjectIdentifier>()
        
        // Build adjacency list: referenced -> [dependents]
        // But for scripting we want: [referenced] -> dependent
        // So we visit dependents and ensure all referenced are visited first.
        var adj: [SQLServerObjectIdentifier: [SQLServerObjectIdentifier]] = [:]
        for dep in dependencies {
            adj[dep.dependentObject, default: []].append(dep.referencedObject)
        }
        
        func visit(_ obj: SQLServerObjectIdentifier) {
            if visited.contains(obj) { return }
            if currentlyVisiting.contains(obj) {
                // Cycle detected - in SQL Server this can happen with views/procs.
                // We break the cycle by just accepting the current state.
                return
            }
            
            currentlyVisiting.insert(obj)
            
            // Visit all objects this object depends on first
            if let refs = adj[obj] {
                for ref in refs {
                    visit(ref)
                }
            }
            
            currentlyVisiting.remove(obj)
            visited.insert(obj)
            result.append(obj)
        }
        
        for obj in objects {
            visit(obj)
        }
        
        return result
    }
}
