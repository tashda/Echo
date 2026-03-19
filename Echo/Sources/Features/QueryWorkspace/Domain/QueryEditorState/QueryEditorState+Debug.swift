import Foundation

extension QueryEditorState {
    /// Represents a user-placed breakpoint at a specific line in the editor.
    struct DebugBreakpoint: Sendable, Equatable, Hashable {
        let lineNumber: Int
    }

    /// Represents the value of a T-SQL variable captured during debug execution.
    struct DebugVariable: Sendable, Equatable, Identifiable {
        var id: String { name }
        let name: String
        let value: String
        let statementIndex: Int
    }

    /// The current phase of a debug session.
    enum DebugPhase: Equatable {
        case idle
        case running
        case paused(atIndex: Int)
        case completed
        case failed(String)
    }
}
