import Foundation

/// A loosely typed JSON value, used for event payloads and sync operations.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON")) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var intValue: Int? { if case .number(let d) = self { return Int(d) }; return nil }
    public static func int(_ v: Int) -> JSONValue { .number(Double(v)) }
    public var doubleValue: Double? { if case .number(let d) = self { return d }; return nil }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    public subscript(key: String) -> JSONValue? { objectValue?[key] }

    public func jsonString(pretty: Bool = false) -> String {
        let e = JSONEncoder()
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return (try? String(data: e.encode(self), encoding: .utf8)) ?? "null"
    }

    public static func parse(_ text: String) -> JSONValue {
        (try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))) ?? .null
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByNilLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(Dictionary(uniqueKeysWithValues: elements)) }
    public init(nilLiteral: ()) { self = .null }
}

public enum RepoRole: String, Codable, CaseIterable, Sendable {
    case app, designSystem = "design-system", specimens, tickets
}

public struct RepoConfig: Codable, Equatable, Sendable {
    public var role: RepoRole
    public var remote: String          // "acme/app"
    public var branch: String          // default/base branch
    public var localPath: String?
    public var buildCommand: String?
    public var testPlans: [String]?
    /// Run in the ticket's workspace by `hatch ready`: the area's tests, never the full suite (decision I3).
    public var testCommand: String?
    /// Compares the built result with the accepted reference (the Match check, CONFORMANCE.md). Optional.
    public var matchCommand: String?
    public init(role: RepoRole, remote: String, branch: String, localPath: String? = nil, buildCommand: String? = nil, testPlans: [String]? = nil,
                testCommand: String? = nil, matchCommand: String? = nil) {
        self.role = role; self.remote = remote; self.branch = branch; self.localPath = localPath
        self.buildCommand = buildCommand; self.testPlans = testPlans; self.testCommand = testCommand; self.matchCommand = matchCommand
    }
}

public struct AreaConfig: Codable, Equatable, Sendable {
    public var name: String
    public var paths: [String]         // globs, e.g. "Echo/Sources/Features/Notifications/**"
    public var specPrefix: String?     // e.g. "NOTIF"
    public var testPlans: [String]?
    public init(name: String, paths: [String], specPrefix: String? = nil, testPlans: [String]? = nil) {
        self.name = name; self.paths = paths; self.specPrefix = specPrefix; self.testPlans = testPlans
    }
}

/// The content of `.hatch/project.json` in the app repo (decision L1).
public struct ProjectConfig: Codable, Equatable, Sendable {
    public var name: String
    public var ticketsRepo: String
    public var repos: [RepoConfig]
    public var areas: [AreaConfig]
    public var docs: [String]
    public var maxAgents: Int
    public var integrationBranch: String
    public var planApprovalFileThreshold: Int

    public init(name: String, ticketsRepo: String, repos: [RepoConfig] = [], areas: [AreaConfig] = [], docs: [String] = [],
                maxAgents: Int = 3, integrationBranch: String = "hatch", planApprovalFileThreshold: Int = 8) {
        self.name = name; self.ticketsRepo = ticketsRepo; self.repos = repos; self.areas = areas; self.docs = docs
        self.maxAgents = maxAgents; self.integrationBranch = integrationBranch; self.planApprovalFileThreshold = planApprovalFileThreshold
    }

    public func repo(_ role: RepoRole) -> RepoConfig? { repos.first { $0.role == role } }

    public func area(containing path: String) -> AreaConfig? {
        areas.first { area in area.paths.contains { Glob.matches($0, path) } }
    }

    public static func load(from url: URL) throws -> ProjectConfig {
        try JSONDecoder().decode(ProjectConfig.self, from: Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try e.encode(self).write(to: url)
    }
}

public struct Project: Identifiable, Equatable, Sendable {
    public let id: Int
    public let key: String
    public var name: String
    public var config: ProjectConfig?
    public let createdAt: Date
}

public struct Repo: Identifiable, Equatable, Sendable {
    public let id: Int
    public let projectId: Int
    public var role: RepoRole
    public var remote: String
    public var defaultBranch: String
    public var localPath: String?
    public var buildCommand: String?
    public var testPlans: [String]
}

public struct Ticket: Identifiable, Equatable, Sendable {
    public let id: Int
    public var ghNumber: Int?
    public var projectId: Int
    public var type: TicketType
    public var status: Status
    public var prevStatus: Status?
    public var turn: Turn
    public var title: String
    public var body: String
    public var originalTitle: String?
    public var originalBody: String?
    public var parentId: Int?
    public var priority: Int
    public var area: String?
    public var revision: Int
    public var takenBy: String?
    public var createdAt: Date
    public var updatedAt: Date

    /// `#151` once the issue exists on GitHub, `new-12` before that.
    public var displayNumber: String { ghNumber.map { "#\($0)" } ?? "new-\(id)" }
}

public struct Event: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let at: Date
    public let actor: String
    public let kind: String
    public let payload: JSONValue
}

public enum NoteKind: String, Codable, CaseIterable, Sendable {
    case comment, note, ask, instruction, agent, system
}

public struct Note: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let kind: NoteKind
    public let author: String
    public let body: String
    public let at: Date
    public let ghCommentId: Int?
    public let context: JSONValue?
}

public enum LinkKind: String, Codable, CaseIterable, Sendable {
    case related, parent, blocks, duplicates, supersedes
}

public struct TicketLink: Equatable, Sendable {
    public let fromId: Int
    public let toId: Int
    public let kind: LinkKind
}

public struct Question: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let text: String
    public let suggestions: [String]
    public let askedBy: String
    public let at: Date
    public var answer: String?
    public var answeredAt: Date?
    public var isOpen: Bool { answer == nil }
}

public struct Attachment: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let path: String
    public let sha: String?
    public let kind: String
    public let caption: String?
    public let at: Date
}

public struct SpecItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let projectId: Int
    public let code: String
    public let area: String?
    public let text: String
    public let source: String?
}

public struct SyncOp: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int?
    public let op: String
    public let payload: JSONValue
    public let direction: String
    public var state: String
    public var attempt: Int
    public var nextAt: Double
    public var error: String?
    public let at: Date
    public var doneAt: Date?
}

public struct TicketFilter: Sendable {
    public var projectId: Int?
    public var statuses: [Status]?
    public var types: [TicketType]?
    public var turn: Turn?
    public var parentId: Int?
    public var area: String?
    public var text: String?
    public var limit: Int?
    public init(projectId: Int? = nil, statuses: [Status]? = nil, types: [TicketType]? = nil, turn: Turn? = nil,
                parentId: Int? = nil, area: String? = nil, text: String? = nil, limit: Int? = nil) {
        self.projectId = projectId; self.statuses = statuses; self.types = types; self.turn = turn
        self.parentId = parentId; self.area = area; self.text = text; self.limit = limit
    }
}

public enum StoreError: Error, CustomStringConvertible, Equatable {
    case notFound(String)
    case invalid(String)
    public var description: String {
        switch self {
        case .notFound(let m): return "Not found: \(m)"
        case .invalid(let m): return m
        }
    }
}
