import SwiftUI

extension WorkspaceTabContainerView {
    func runQuery(tabId: UUID, sql: String) async {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        while effectiveSQL.last == ";" {
            effectiveSQL.removeLast()
        }
        effectiveSQL = effectiveSQL.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveSQL.isEmpty {
            effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        }
        let inferredObject = inferPrimaryObjectName(from: effectiveSQL)
        await MainActor.run {
            queryState.updateClipboardObjectName(inferredObject)
        }
        let foreignKeyMode = await MainActor.run { projectStore.globalSettings.foreignKeyDisplayMode }
        let shouldResolveForeignKeys = foreignKeyMode != .disabled
        let foreignKeySource = shouldResolveForeignKeys ? resolveSchemaAndTable(for: inferredObject, connection: tab.connection) : nil

        let task = Task { [weak queryState] in
            guard let state = await MainActor.run(body: { queryState }) else { return }

            do {
                await MainActor.run {
                    state.recordQueryDispatched()
                    if let source = foreignKeySource {
                        state.updateForeignKeyResolutionContext(schema: source.schema, table: source.table)
                    } else {
                        state.updateForeignKeyResolutionContext(schema: nil, table: nil)
                    }
                }
                let perQueryMode = await MainActor.run { state.streamingModeOverride }
                let executionMode: ResultStreamingExecutionMode? = perQueryMode == .auto ? nil : perQueryMode
                let result = try await tab.session.simpleQuery(effectiveSQL, executionMode: executionMode) { [weak state] update in
                    guard let state else { return }

                    Task { @MainActor in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            state.applyStreamUpdate(update)
                        }
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    state.consumeFinalResult(result)
                    state.finishExecution()

                    var metadata: [String: String] = [
                        "rows": "\(result.rows.count)"
                    ]
                    let columnNames = result.columns.map(\.name).joined(separator: ", ")
                    if !columnNames.isEmpty {
                        metadata["columns"] = columnNames
                    }
                    if let commandTag = result.commandTag, !commandTag.isEmpty {
                        metadata["commandTag"] = commandTag
                    }

                    state.appendMessage(
                        message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    appState.addToQueryHistory(effectiveSQL, resultCount: result.rows.count, duration: state.lastExecutionTime ?? 0)
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.startExecution()
            queryState.setExecutingTask(task)
            environmentState.dataInspectorContent = nil
        }
    }

    func cancelQuery(tabId: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == tabId }),
              let queryState = tab.query else { return }
        queryState.cancelExecution()
    }

    func inferPrimaryObjectName(from sql: String) -> String? {
        let cleanedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSQL.isEmpty else { return nil }

        let patterns = [
            #"(?i)\bfrom\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\binto\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bupdate\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bdelete\s+from\s+([A-Za-z0-9_\.\"`]+)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: cleanedSQL, pattern: pattern) {
                return normalizeIdentifier(match)
            }
        }

        return nil
    }

    func firstMatch(in sql: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (sql as NSString).length)
        guard let match = regex.firstMatch(in: sql, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let matchRange = match.range(at: 1)
        guard let rangeInString = Range(matchRange, in: sql) else { return nil }
        return String(sql[rangeInString])
    }

    func normalizeIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'[]"))
        return trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "].[", with: ".")
    }

    func resolveSchemaAndTable(for identifier: String?, connection: SavedConnection) -> (schema: String, table: String)? {
        guard let identifier, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let components = parseQualifiedIdentifier(identifier)
        guard let table = components.last, !table.isEmpty else { return nil }
        let schemaCandidate = components.count >= 2 ? components[components.count - 2] : nil
        let effectiveSchema: String?
        if let schemaCandidate, !schemaCandidate.isEmpty {
            effectiveSchema = schemaCandidate
        } else {
            effectiveSchema = defaultSchema(for: connection.databaseType, connection: connection)
        }

        switch connection.databaseType {
        case .mysql, .sqlite:
            let schema = effectiveSchema ?? connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        default:
            guard let schema = effectiveSchema, !schema.isEmpty else { return nil }
            return (schema: schema, table: table)
        }
    }

    func parseQualifiedIdentifier(_ identifier: String) -> [String] {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let sanitized = trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        return sanitized.split(separator: ".").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func defaultSchema(for type: DatabaseType, connection: SavedConnection) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql:
            let database = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
            return database.isEmpty ? nil : database
        case .sqlite:
            return "main"
        }
    }
}
