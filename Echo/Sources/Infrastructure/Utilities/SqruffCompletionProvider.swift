import Foundation
import OSLog
import EchoSense

actor SqruffCompletionProvider {
    static let shared = SqruffCompletionProvider()

    enum ProviderError: Error {
        case binaryNotFound
        case connectionClosed
        case serverError(String)
        case invalidResponse
    }

    private struct SendableJSON: @unchecked Sendable {
        let value: Any
    }

    private let logger = Logger(subsystem: "co.fuze.echo", category: "Sqruff")

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?

    private var readBuffer = Data()
    private var pending: [Int: CheckedContinuation<SendableJSON, Error>] = [:]
    private var nextRequestID: Int = 1

    private var initialized = false
    private var didOpenDocument = false
    private var documentVersion = 0
    private var currentDialect: DatabaseType?

    private let documentURI = "file:///sqruff/virtual.sql"
    private nonisolated let delimiterData = "\r\n\r\n".data(using: .utf8)!

    deinit {
        Task { [weak self] in
            guard let self else { return }
            await self.shutdownProcess()
        }
    }

    func completions(forText text: String,
                     line: Int,
                     character: Int,
                     dialect: DatabaseType) async throws -> [SQLAutoCompletionSuggestion] {
        try await ensureConnection(for: dialect)

        try await openOrUpdateDocument(text)

        let params: [String: Any] = [
            "textDocument": ["uri": documentURI],
            "position": ["line": line, "character": character]
        ]

        let result = try await sendRequest(method: "textDocument/completion", params: params)
        let suggestions = await SqruffCompletionProvider.parseCompletionResult(result)
        return suggestions
    }

    // MARK: - Connection Management

    private func ensureConnection(for dialect: DatabaseType) async throws {
        if let process, process.isRunning, initialized, currentDialect == dialect {
            return
        }
        try await startProcess(for: dialect)
    }

    private func startProcess(for dialect: DatabaseType) async throws {
        await shutdownProcess()

        guard let binaryURL = resolveBinaryURL() else {
            throw ProviderError.binaryNotFound
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["lsp"]
        process.standardInput = Pipe()
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        process.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }

        try process.run()

        guard let stdinPipe = process.standardInput as? Pipe,
              let stdoutPipe = process.standardOutput as? Pipe,
              let stderrPipe = process.standardError as? Pipe else {
            throw ProviderError.connectionClosed
        }

        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutHandle = stdoutPipe.fileHandleForReading
        stderrHandle = stderrPipe.fileHandleForReading
        self.process = process
        currentDialect = dialect
        initialized = false
        didOpenDocument = false
        documentVersion = 0
        readBuffer.removeAll(keepingCapacity: true)

        stdoutHandle?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { [weak self] in
                await self?.receive(data: data)
            }
        }

        stderrHandle?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { [weak self] in
                if let message = String(data: data, encoding: .utf8) {
                    self?.logger.debug("sqruff stderr: \(message)")
                }
            }
        }

        try await initializeServer(dialect: dialect)
    }

    private func shutdownProcess() async {
        if let stdoutHandle {
            stdoutHandle.readabilityHandler = nil
        }
        if let stderrHandle {
            stderrHandle.readabilityHandler = nil
        }

        stdinHandle?.closeFile()
        stdoutHandle?.closeFile()
        stderrHandle?.closeFile()

        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil

        if let process {
            process.terminationHandler = nil
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        process = nil
        initialized = false
        didOpenDocument = false
        documentVersion = 0
        currentDialect = nil
        readBuffer.removeAll(keepingCapacity: true)

        if !pending.isEmpty {
            let continuations = pending
            pending.removeAll()
            for (_, continuation) in continuations {
                continuation.resume(throwing: ProviderError.connectionClosed)
            }
        }
    }

    private func handleTermination() async {
        logger.debug("sqruff process terminated")
        await shutdownProcess()
    }

    private func initializeServer(dialect: DatabaseType) async throws {
        let capabilities: [String: Any] = [:]
        let initParams: [String: Any] = [
            "processId": ProcessInfo.processInfo.processIdentifier,
            "clientInfo": ["name": "Echo", "version": "1.0"],
            "rootUri": NSNull(),
            "capabilities": capabilities,
            "initializationOptions": ["dialect": dialectIdentifier(for: dialect)]
        ]

        _ = try await sendRequest(method: "initialize", params: initParams)
        try await sendNotification(method: "initialized", params: [:])
        initialized = true
    }

    // MARK: - Document Management

    private func openOrUpdateDocument(_ text: String) async throws {
        if !didOpenDocument {
            documentVersion = 1
            let params: [String: Any] = [
                "textDocument": [
                    "uri": documentURI,
                    "languageId": "sql",
                    "version": documentVersion,
                    "text": text
                ]
            ]
            try await sendNotification(method: "textDocument/didOpen", params: params)
            didOpenDocument = true
        } else {
            documentVersion += 1
            let params: [String: Any] = [
                "textDocument": [
                    "uri": documentURI,
                    "version": documentVersion
                ],
                "contentChanges": [["text": text]]
            ]
            try await sendNotification(method: "textDocument/didChange", params: params)
        }
    }

    // MARK: - Messaging

    private func sendNotification(method: String, params: [String: Any]) async throws {
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ]
        try sendMessage(message)
    }

    private func sendRequest(method: String, params: [String: Any]) async throws -> Any {
        let requestID = nextRequestID
        nextRequestID += 1

        let wrapped: SendableJSON = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SendableJSON, Error>) in
            pending[requestID] = continuation
            let message: [String: Any] = [
                "jsonrpc": "2.0",
                "id": requestID,
                "method": method,
                "params": params
            ]
            do {
                try sendMessage(message)
            } catch {
                if let pendingContinuation = pending.removeValue(forKey: requestID) {
                    pendingContinuation.resume(throwing: error)
                }
            }
        }
        return wrapped.value
    }

    private func sendMessage(_ json: [String: Any]) throws {
        guard let stdinHandle else {
            throw ProviderError.connectionClosed
        }
        let body = try JSONSerialization.data(withJSONObject: json, options: [])
        guard let headerData = "Content-Length: \(body.count)\r\n\r\n".data(using: .utf8) else {
            throw ProviderError.invalidResponse
        }
        stdinHandle.write(headerData)
        stdinHandle.write(body)
    }

    private func receive(data: Data) async {
        guard !data.isEmpty else { return }
        readBuffer.append(data)
        parseBuffer()
    }

    private func parseBuffer() {
        while true {
            guard let delimiterRange = readBuffer.range(of: delimiterData) else { break }
            let headerData = readBuffer.subdata(in: 0..<delimiterRange.lowerBound)
            guard let headerString = String(data: headerData, encoding: .utf8) else {
                readBuffer.removeAll()
                break
            }

            var contentLength: Int?
            headerString.split(separator: "\r\n").forEach { line in
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2, parts[0].caseInsensitiveCompare("Content-Length") == .orderedSame {
                    contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
                }
            }

            guard let length = contentLength else {
                readBuffer.removeAll()
                break
            }

            let messageStart = delimiterRange.upperBound
            let messageEnd = messageStart + length
            guard readBuffer.count >= messageEnd else { break }

            let messageData = readBuffer.subdata(in: messageStart..<messageEnd)
            readBuffer.removeSubrange(0..<messageEnd)

            handleMessageData(messageData)
        }
    }

    private func handleMessageData(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let message = object as? [String: Any] else {
            logger.warning("sqruff: received non-JSON message")
            return
        }

        if let idValue = message["id"] {
            handleResponse(idValue: idValue, message: message)
        } else if let method = message["method"] as? String {
            logger.debug("sqruff notification: \(method)")
        }
    }

    private func handleResponse(idValue: Any, message: [String: Any]) {
        let identifier: Int?
        if let intID = idValue as? Int {
            identifier = intID
        } else if let stringID = idValue as? String {
            identifier = Int(stringID)
        } else {
            identifier = nil
        }

        guard let id = identifier, let continuation = pending.removeValue(forKey: id) else {
            return
        }

        if let error = message["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            continuation.resume(throwing: ProviderError.serverError(message))
        } else if let result = message["result"] {
            continuation.resume(returning: SendableJSON(value: result))
        } else {
            continuation.resume(throwing: ProviderError.invalidResponse)
        }
    }

    private func resolveBinaryURL() -> URL? {
        let fileManager = FileManager.default

        if let bundleURL = Bundle.main.url(forResource: "sqruff", withExtension: nil) {
            return bundleURL
        }

        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("sqruff"),
           fileManager.isExecutableFile(atPath: resourceURL.path) {
            return resourceURL
        }

        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates = [
            currentDirectory.appendingPathComponent("BuildTools/sqruff/sqruff"),
            currentDirectory.appendingPathComponent("../BuildTools/sqruff/sqruff")
        ]

        for url in candidates {
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private func dialectIdentifier(for type: DatabaseType) -> String {
        switch type {
        case .postgresql: return "postgres"
        case .mysql: return "mysql"
        case .microsoftSQL: return "tsql"
        case .sqlite: return "sqlite"
        }
    }

    private static func parseCompletionResult(_ result: Any) async -> [SQLAutoCompletionSuggestion] {
        let itemsArray: [[String: Any]]

        if let dict = result as? [String: Any], let items = dict["items"] as? [[String: Any]] {
            itemsArray = items
        } else if let array = result as? [[String: Any]] {
            itemsArray = array
        } else {
            return []
        }

        var suggestions: [SQLAutoCompletionSuggestion] = []
        suggestions.reserveCapacity(itemsArray.count)

        var seen = Set<String>()

        for item in itemsArray {
            guard let label = item["label"] as? String else { continue }

            let rawInsertText: String
            if let textEdit = item["textEdit"] as? [String: Any], let newText = textEdit["newText"] as? String {
                rawInsertText = newText
            } else if let providedInsert = item["insertText"] as? String {
                rawInsertText = providedInsert
            } else {
                rawInsertText = label
            }

            let cleanedInsertText = cleanInsertText(rawInsertText)
            let key = cleanedInsertText.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)

            let detail = item["detail"] as? String

            let kindValue = item["kind"] as? Int
            let kind = mapCompletionKind(kindValue, detail: detail, label: label)

            let suggestionID = "sqruff::\(label)::\(cleanedInsertText)"
            let suggestion = await MainActor.run {
                SQLAutoCompletionSuggestion(
                    id: suggestionID,
                    title: label,
                    subtitle: detail,
                    detail: detail,
                    insertText: cleanedInsertText,
                    kind: kind
                )
            }
            suggestions.append(suggestion)
        }

        return suggestions
    }

    private static func cleanInsertText(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "\r", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")
        for index in 0..<10 {
            cleaned = cleaned.replacingOccurrences(of: "${\(index)}", with: "")
            cleaned = cleaned.replacingOccurrences(of: "$\(index)", with: "")
        }
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mapCompletionKind(_ value: Int?, detail: String?, label: String) -> SQLAutoCompletionKind {
        if let detail = detail?.lowercased() {
            if detail.contains("table") { return .table }
            if detail.contains("view") { return .view }
            if detail.contains("column") { return .column }
            if detail.contains("function") { return .function }
            if detail.contains("keyword") { return .keyword }
        }

        if let labelLower = label.split(separator: " ").first?.lowercased(), labelLower == "insert" || labelLower == "update" || labelLower == "delete" || labelLower == "select" {
            return .keyword
        }

        switch value {
        case 3, 4: return .function
        case 2: return .function
        case 5, 6, 21: return .column
        case 7, 8, 9, 22: return .table
        case 10, 11, 13: return .view
        case 12: return .keyword
        default:
            return .keyword
        }
    }
}
