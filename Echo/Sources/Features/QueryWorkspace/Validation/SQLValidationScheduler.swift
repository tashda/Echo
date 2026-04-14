import Foundation
import EchoSense
import OSLog

/// Schedules debounced SQL validation triggered after text changes.
/// Cancels pending validation when new edits arrive.
/// Runs validation on a background queue, delivers results on main thread.
final class SQLValidationScheduler: Sendable {
    private let debounceInterval: TimeInterval
    private let validator = SQLQueryValidator()

    /// Current validation generation — incremented on each schedule, used to discard stale results
    private let generation = OSAllocatedUnfairLock(initialState: 0)

    init(debounceInterval: TimeInterval = 0.8) {
        self.debounceInterval = debounceInterval
    }

    /// Schedule a validation run. Cancels any pending run.
    /// - Parameters:
    ///   - sql: The SQL text to validate
    ///   - context: Completion context containing metadata
    ///   - onResult: Called on MainActor with diagnostics (empty array = no issues)
    func schedule(
        sql: String,
        context: SQLEditorCompletionContext?,
        onResult: @MainActor @Sendable @escaping ([SQLDiagnostic]) -> Void
    ) {
        let currentGen = generation.withLock { value -> Int in
            value += 1
            return value
        }

        // Empty SQL or no context → clear diagnostics immediately
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let context else {
            Task { @MainActor in onResult([]) }
            return
        }

        Task.detached(priority: .utility) { [validator, generation, debounceInterval] in
            try? await Task.sleep(for: .milliseconds(Int(debounceInterval * 1000)))

            // Check if we're still the latest generation
            let isStale = generation.withLock { $0 != currentGen }
            guard !isStale else { return }

            let diagnostics = await validator.validate(
                sql: sql,
                structure: context.structure,
                selectedDatabase: context.selectedDatabase,
                defaultSchema: context.defaultSchema,
                dialect: context.databaseType
            )

            // Check again after validation completes
            let isStaleAfter = generation.withLock { $0 != currentGen }
            guard !isStaleAfter else { return }

            await MainActor.run { onResult(diagnostics) }
        }
    }

    /// Run validation immediately (no debounce) for on-demand mode.
    func validateNow(
        sql: String,
        context: SQLEditorCompletionContext?,
        onResult: @MainActor @Sendable @escaping ([SQLDiagnostic]) -> Void
    ) {
        let currentGen = generation.withLock { value -> Int in
            value += 1
            return value
        }

        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let context else {
            Task { @MainActor in onResult([]) }
            return
        }

        Task.detached(priority: .utility) { [validator, generation] in
            let diagnostics = await validator.validate(
                sql: sql,
                structure: context.structure,
                selectedDatabase: context.selectedDatabase,
                defaultSchema: context.defaultSchema,
                dialect: context.databaseType
            )

            let isStale = generation.withLock { $0 != currentGen }
            guard !isStale else { return }

            await MainActor.run { onResult(diagnostics) }
        }
    }

    /// Cancel any pending validation
    func cancel() {
        generation.withLock { $0 += 1 }
    }
}
