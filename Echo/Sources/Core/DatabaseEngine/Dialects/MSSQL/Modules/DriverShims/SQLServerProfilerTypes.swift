import SQLServerKit
import Foundation

/// A legacy SQL Trace event identifier, as used by SQL Profiler.
/// These can be mapped to modern Extended Events for a unified backend.
public enum SQLTraceEvent: Int, Sendable, CaseIterable {
    case rpcCompleted = 10
    case rpcStarting = 11
    case sqlBatchCompleted = 12
    case sqlBatchStarting = 13
    case login = 14
    case logout = 15
    case attention = 16
    case existingConnection = 17
    case serviceControl = 18
    case dtcTransaction = 19
    case rpcOutputParameter = 20
    case transactionLog = 21
    case errorLog = 22
    case lockReleased = 23
    case lockAcquired = 24
    case lockDeadlock = 25
    case lockCancel = 26
    case lockTimeout = 27
    case degreeOfParallelism = 28
    case scanStarted = 33
    case scanStopped = 34
    case sqlStatementCompleted = 41
    case sqlStatementStarting = 40
    case deadlockGraph = 148
    
    /// Returns the modern Extended Event name for this legacy Trace ID.
    public var xeEventName: String {
        switch self {
        case .rpcCompleted: return "rpc_completed"
        case .rpcStarting: return "rpc_starting"
        case .sqlBatchCompleted: return "sql_batch_completed"
        case .sqlBatchStarting: return "sql_batch_starting"
        case .login: return "login"
        case .logout: return "logout"
        case .attention: return "attention"
        case .existingConnection: return "existing_connection"
        case .serviceControl: return "service_control"
        case .dtcTransaction: return "dtc_transaction"
        case .rpcOutputParameter: return "rpc_output_parameter"
        case .transactionLog: return "transaction_log"
        case .errorLog: return "error_log"
        case .lockReleased: return "lock_released"
        case .lockAcquired: return "lock_acquired"
        case .lockDeadlock: return "lock_deadlock"
        case .lockCancel: return "lock_cancel"
        case .lockTimeout: return "lock_timeout"
        case .degreeOfParallelism: return "degree_of_parallelism"
        case .scanStarted: return "scan_started"
        case .scanStopped: return "scan_stopped"
        case .sqlStatementCompleted: return "sql_statement_completed"
        case .sqlStatementStarting: return "sql_statement_starting"
        case .deadlockGraph: return "xml_deadlock_report"
        }
    }
}

/// A captured event from a Profiler trace session.
public struct SQLServerProfilerEvent: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let eventName: String
    public let timestamp: Date?
    public let textData: String?
    public let databaseName: String?
    public let loginName: String?
    public let duration: Int64?
    public let cpu: Int?
    public let reads: Int64?
    public let writes: Int64?
    public let spid: Int?
    
    public init(
        id: UUID = UUID(),
        eventName: String,
        timestamp: Date?,
        textData: String?,
        databaseName: String?,
        loginName: String?,
        duration: Int64?,
        cpu: Int?,
        reads: Int64?,
        writes: Int64?,
        spid: Int?
    ) {
        self.id = id
        self.eventName = eventName
        self.timestamp = timestamp
        self.textData = textData
        self.databaseName = databaseName
        self.loginName = loginName
        self.duration = duration
        self.cpu = cpu
        self.reads = reads
        self.writes = writes
        self.spid = spid
    }
}
