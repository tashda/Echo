import Foundation
import Logging

public struct PostgresNotification: Sendable, Equatable {
    public let channel: String
    public let payload: String?
    public let pid: Int32?
}

public actor PostgresNotifier {
    private let client: PostgresDatabaseClient
    private let logger: Logger
    private var listeningTask: Task<Void, Never>?
    public typealias Handler = @Sendable (PostgresNotification) -> Void
    private var handlers: [String: [Handler]] = [:] // channel -> handlers
    // AsyncStream continuations per channel
    private struct StreamEntry: Sendable, Equatable {
        let id: UUID
        let continuation: AsyncStream<PostgresNotification>.Continuation
        static func == (lhs: StreamEntry, rhs: StreamEntry) -> Bool { lhs.id == rhs.id }
    }
    private var streams: [String: [StreamEntry]] = [:]
    private var listenTokens: [String: [WireConnection.WireListenToken]] = [:]

    public init(client: PostgresDatabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    public func notify(channel: String, payload: String? = nil) async throws {
        let sql: String
        if let payload {
            let quoted = payload.replacingOccurrences(of: "'", with: "''")
            sql = "NOTIFY \(quoteIdent(channel)), '\(quoted)'"
        } else {
            sql = "NOTIFY \(quoteIdent(channel))"
        }
        _ = try await client.simpleQuery(sql)
    }

    public func listen(channels: [String]) async throws {
        // Cancel previous listening task and tokens
        listeningTask?.cancel()
        listeningTask = nil
        // Normalize keys
        let normalized = channels.map { $0.lowercased() }
        // Start a supervisor task that re-establishes LISTEN after reconnects
        listeningTask = Task { [weak self, client, logger] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await client.withConnection { conn in
                        // Register listeners per channel and issue LISTEN
                        for channel in normalized {
                            // stop and clear any existing tokens for this channel
                            if let tokens = await self.listenTokens[channel] {
                                tokens.forEach { $0.stop() }
                                await self.setTokens([], for: channel)
                            }
                            // Register a listener that fans-out to handlers & streams
                            let token = conn.addNotificationListener(channel: channel) { [weak self] note in
                                guard let self else { return }
                                Task { await self.deliver(channel: note.channel, payload: note.payload, pid: note.pid) }
                            }
                            await self.appendToken(token, for: channel)
                            // LISTEN on the server
                            _ = try await conn.simpleQuery("LISTEN \(quoteIdent(channel))")
                        }
                        // Suspend until the connection closes or task is cancelled
                        await conn.waitForClose()
                    }
                } catch {
                    logger.warning("Listen loop error: \(String(describing: error))")
                }
                // Small backoff before retrying
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    public func stop() {
        listeningTask?.cancel()
        listeningTask = nil
    }

    public func registerHandler(for channel: String, handler: @escaping Handler) {
        let key = channel.lowercased()
        handlers[key, default: []].append(handler)
    }

    public func removeHandlers(for channel: String) {
        handlers[channel.lowercased()] = []
    }

    public func unlisten(channel: String) async throws {
        let key = channel.lowercased()
        // stop local tokens
        if let tokens = listenTokens.removeValue(forKey: key) {
            tokens.forEach { $0.stop() }
        }
        // issue UNLISTEN on a temp connection
        try await client.withConnection { conn in
            _ = try await conn.simpleQuery("UNLISTEN \(quoteIdent(key))")
        }
        handlers[key] = []
        if let list = streams.removeValue(forKey: key) {
            list.forEach { $0.continuation.finish() }
        }
    }

    // Subscribe to notifications for a given channel as an AsyncStream
    public func notifications(for channel: String) -> AsyncStream<PostgresNotification> {
        let key = channel.lowercased()
        return AsyncStream { continuation in
            let entry = StreamEntry(id: UUID(), continuation: continuation)
            streams[key, default: []].append(entry)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStream(id: entry.id, for: key) }
            }
        }
    }

    // Bridge for the wire layer to deliver a notification
    public func deliver(channel: String, payload: String?, pid: Int32?) {
        let key = channel.lowercased()
        let note = PostgresNotification(channel: key, payload: payload, pid: pid)
        if let list = handlers[key] {
            list.forEach { $0(note) }
        }
        if let entries = streams[key] {
            entries.forEach { $0.continuation.yield(note) }
        }
    }

    private func removeStream(id: UUID, for key: String) {
        guard var list = streams[key] else { return }
        list.removeAll { $0.id == id }
        streams[key] = list
    }

    private func quoteIdent(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func setTokens(_ tokens: [WireConnection.WireListenToken], for channel: String) {
        listenTokens[channel] = tokens
    }

    private func appendToken(_ token: WireConnection.WireListenToken, for channel: String) {
        listenTokens[channel, default: []].append(token)
    }
}
