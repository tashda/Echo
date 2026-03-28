import Foundation
import MySQLKit
import Observation

@Observable @MainActor
final class ServerPropertiesViewModel {
    enum Section: String, CaseIterable {
        case overview = "Overview"
        case variables = "Variables"
        case logs = "Logs"
    }

    struct PropertyItem: Identifiable {
        let id: String
        let name: String
        let value: String
        let category: String?

        init(id: String, name: String, value: String, category: String? = nil) {
            self.id = id
            self.name = name
            self.value = value
            self.category = category
        }
    }

    struct LogRow: Identifiable {
        let id: String
        let timestamp: String
        let summary: String
        let details: String
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored private(set) var panelState: BottomPanelState?

    var selectedSection: Section = .overview
    var isInitialized = false
    var isLoading = false
    var searchText = ""
    var selectedVariableID: Set<String> = []

    var overviewItems: [PropertyItem] = []
    var variables: [PropertyItem] = []
    var logDestinations: [PropertyItem] = []
    var errorLogRows: [LogRow] = []
    var generalLogRows: [LogRow] = []
    var slowLogRows: [LogRow] = []

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        panelState = state
    }

    func initialize() async {
        isInitialized = true
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let mysql = session as? MySQLSession else { return }
        switch selectedSection {
        case .overview:
            await loadOverview(mysql: mysql)
        case .variables:
            await loadVariables(mysql: mysql)
        case .logs:
            await loadLogs(mysql: mysql)
        }
    }

    var filteredVariables: [PropertyItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return variables }
        return variables.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.value.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedVariable: PropertyItem? {
        variables.first { selectedVariableID.contains($0.id) }
    }

    var variableCategories: [String] {
        Array(Set(variables.compactMap(\.category)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func loadOverview(mysql: MySQLSession) async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading server overview", connectionSessionID: connectionSessionID)
        do {
            async let variablesResult = mysql.client.admin.globalVariables()
            async let statusResult = mysql.client.admin.globalStatus()
            let variables = try await variablesResult
            let status = try await statusResult
            overviewItems = buildOverviewItems(variables: variables, status: status)
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load server overview: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadVariables(mysql: MySQLSession) async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading server variables", connectionSessionID: connectionSessionID)
        do {
            variables = try await mysql.client.admin.globalVariables()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map {
                    PropertyItem(
                        id: $0.name,
                        name: $0.name,
                        value: $0.value,
                        category: variableCategory(for: $0.name)
                    )
                }
            if selectedVariable == nil {
                selectedVariableID = variables.first.map { [$0.id] } ?? []
            }
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load server variables: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadLogs(mysql: MySQLSession) async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading server log settings", connectionSessionID: connectionSessionID)
        do {
            let destinations = try await mysql.client.admin.logDestinations()
            logDestinations = destinations.map {
                PropertyItem(id: $0.kind, name: $0.kind, value: $0.value)
            }

            errorLogRows = []
            generalLogRows = []
            slowLogRows = []

            let logOutput = destinations.first(where: { $0.kind.lowercased() == "log_output" })?.value.uppercased() ?? ""
            if logOutput.contains("TABLE") {
                generalLogRows = try await loadLogRows(mysql: mysql, tableName: "general_log")
                slowLogRows = try await loadLogRows(mysql: mysql, tableName: "slow_log")
            }

            if let errorLogPath = logPath(named: "log_error", in: destinations) {
                errorLogRows = try loadFileLogRows(path: errorLogPath, kind: "error")
            }

            if generalLogRows.isEmpty, let generalLogPath = logPath(named: "general_log_file", in: destinations) {
                generalLogRows = try loadFileLogRows(path: generalLogPath, kind: "general")
            }

            if slowLogRows.isEmpty, let slowLogPath = logPath(named: "slow_query_log_file", in: destinations) {
                slowLogRows = try loadFileLogRows(path: slowLogPath, kind: "slow")
            }
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load MySQL log settings: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadLogRows(mysql: MySQLSession, tableName: String) async throws -> [LogRow] {
        let rows = try await mysql.client.admin.readTableLog(named: tableName, limit: 25)
        return rows.enumerated().map { offset, row in
            let timestamp = row["event_time"] ?? row["start_time"] ?? "\u{2014}"
            let userHost = row["user_host"] ?? row["user"] ?? ""
            let command = row["command_type"] ?? row["command"] ?? ""
            let argument = row["argument"] ?? row["sql_text"] ?? row["host"] ?? ""
            let summary = [userHost, command, argument]
                .map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
                .filter { !$0.isEmpty }
                .joined(separator: " \u{2022} ")
            let details = row
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value ?? "\u{2014}")" }
                .joined(separator: "\n")
            return LogRow(
                id: "\(tableName)-\(offset)-\(timestamp)",
                timestamp: timestamp ?? "\u{2014}",
                summary: summary.isEmpty ? "Log row" : summary,
                details: details
            )
        }
    }

    private func logPath(named name: String, in destinations: [MySQLLogDestination]) -> String? {
        destinations.first(where: { $0.kind.lowercased() == name.lowercased() })?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func loadFileLogRows(path: String, kind: String, limit: Int = 100) throws -> [LogRow] {
        let normalizedPath = NSString(string: path).expandingTildeInPath
        let contents = try String(contentsOfFile: normalizedPath, encoding: .utf8)
        let lines = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tail = Array(lines.suffix(limit))

        return tail.enumerated().map { offset, line in
            LogRow(
                id: "\(kind)-file-\(offset)-\(line.hashValue)",
                timestamp: extractTimestamp(from: line) ?? "\u{2014}",
                summary: line,
                details: "Path: \(normalizedPath)\n\n\(line)"
            )
        }
    }

    private func extractTimestamp(from line: String) -> String? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let first = parts.first else { return nil }
        let token = String(first)
        if token.contains("-") || token.contains(":") || token.contains("T") {
            return token
        }
        return nil
    }

    private func buildOverviewItems(
        variables: [MySQLGlobalVariable],
        status: [MySQLStatusVariable]
    ) -> [PropertyItem] {
        let variableMap = Dictionary(uniqueKeysWithValues: variables.map { ($0.name.lowercased(), $0.value) })
        let statusMap = Dictionary(uniqueKeysWithValues: status.map { ($0.name.lowercased(), $0.value) })

        let raw: [(String, String)] = [
            ("Version", variableMap["version"] ?? "\u{2014}"),
            ("Edition", variableMap["version_comment"] ?? "\u{2014}"),
            ("Hostname", variableMap["hostname"] ?? "\u{2014}"),
            ("Port", variableMap["port"] ?? "\u{2014}"),
            ("Server Charset", variableMap["character_set_server"] ?? "\u{2014}"),
            ("Server Collation", variableMap["collation_server"] ?? "\u{2014}"),
            ("SQL Mode", variableMap["sql_mode"] ?? "\u{2014}"),
            ("Max Connections", variableMap["max_connections"] ?? "\u{2014}"),
            ("Buffer Pool Size", variableMap["innodb_buffer_pool_size"] ?? "\u{2014}"),
            ("Uptime", statusMap["uptime"] ?? "\u{2014}"),
            ("Threads Connected", statusMap["threads_connected"] ?? "\u{2014}"),
            ("Questions", statusMap["questions"] ?? "\u{2014}"),
            ("Slow Queries", statusMap["slow_queries"] ?? "\u{2014}")
        ]

        return raw.map {
            PropertyItem(
                id: $0.0.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: $0.0,
                value: $0.1,
                category: nil
            )
        }
    }

    private func variableCategory(for variableName: String) -> String {
        let normalized = variableName.lowercased()
        if let prefix = normalized.split(separator: "_").first, !prefix.isEmpty {
            return prefix.uppercased()
        }
        return "GENERAL"
    }

    func setSelectedVariable(to value: String) async {
        guard let mysql = session as? MySQLSession, let variable = selectedVariable else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let handle = activityEngine?.begin("Updating \(variable.name)", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.admin.setGlobalVariable(variable.name, to: trimmed)
            handle?.succeed()
            panelState?.appendMessage("Updated global variable \(variable.name)")
            await loadVariables(mysql: mysql)
            await loadOverview(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update global variable \(variable.name): \(error.localizedDescription)", severity: .error)
        }
    }

    func resetSelectedVariable() async {
        guard let mysql = session as? MySQLSession, let variable = selectedVariable else { return }
        let handle = activityEngine?.begin("Resetting \(variable.name)", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.admin.resetGlobalVariable(variable.name)
            handle?.succeed()
            panelState?.appendMessage("Reset global variable \(variable.name)")
            await loadVariables(mysql: mysql)
            await loadOverview(mysql: mysql)
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to reset global variable \(variable.name): \(error.localizedDescription)", severity: .error)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
