import Foundation

extension QueryExecutionMessage {
    /// SQL Server's numbers for an error, as the error banner's quiet chips (round 41.3, ED0):
    /// `Msg 248`, `Level 16`, `State 1`. Empty for anything else.
    var errorChips: [String] {
        guard severity == .error, let number = metadata["messageNumber"],
              let level = metadata["level"], let state = metadata["state"] else { return [] }
        return ["Msg \(number)", "Level \(level)", "State \(state)"]
    }

    /// The chips of the error a failed run reported: its last server error with numbers.
    static func errorChips(in messages: [QueryExecutionMessage]) -> [String] {
        messages.last { !$0.errorChips.isEmpty }?.errorChips ?? []
    }
}
