import EchoLocalStorage
import Foundation
import OSLog
import Synchronization

/// Synchronous memory reads keep tree interaction immediate; disk state uses the encrypted archive.
nonisolated enum ExplorerStateStore {
    private enum Value: Codable, Sendable { case string(String), bool(Bool), data(Data) }
    private struct State { var values: [String: Value] = [:]; var revision: UInt64 = 0; var available = false }
    private static let state = Mutex(State())
    static var defaults: UserDefaults { UserDefaults(suiteName: "dev.echodb.echo.explorer") ?? .standard }

    static func hydrate() async throws {
        var legacy: [String: Any] = [:]
        if !EncryptedRecordStore.isTestHost {
            legacy = UserDefaults.standard.dictionaryRepresentation().filter {
            $0.key.hasPrefix("echo.sidebar.") || $0.key == "experimentalObjectBrowser.sidebarStateByProject"
        }
            legacy.merge(defaults.dictionaryRepresentation().filter {
                $0.key.hasPrefix("echo.sidebar.") || $0.key == "experimentalObjectBrowser.sidebarStateByProject"
            }) { _, suite in suite }
        }
        let legacyValues = legacy.compactMapValues(value)
        let data = try await LocalArchive.shared.load(collection: "explorer-state", legacyData: LocalRecordEncoding.encode(legacyValues))
        let values = try data.map { try JSONDecoder().decode([String: Value].self, from: $0) } ?? [:]
        state.withLock { $0.values = values; $0.available = true }
        for key in legacy.keys { defaults.removeObject(forKey: key); UserDefaults.standard.removeObject(forKey: key) }
    }

    static func string(forKey key: String) -> String? {
        if case .string(let value) = state.withLock({ $0.values[key] }) { return value }
        return state.withLock { $0.available } || EncryptedRecordStore.isTestHost ? nil : (defaults.string(forKey: key) ?? UserDefaults.standard.string(forKey: key))
    }
    static func data(forKey key: String) -> Data? {
        if case .data(let value) = state.withLock({ $0.values[key] }) { return value }
        return state.withLock { $0.available } || EncryptedRecordStore.isTestHost ? nil : (defaults.data(forKey: key) ?? UserDefaults.standard.data(forKey: key))
    }
    static func bool(forKey key: String) -> Bool? {
        if case .bool(let value) = state.withLock({ $0.values[key] }) { return value }
        return state.withLock { $0.available } || EncryptedRecordStore.isTestHost ? nil : ((defaults.object(forKey: key) ?? UserDefaults.standard.object(forKey: key)) as? Bool)
    }

    static func set(_ newValue: Any?, forKey key: String) {
        let (snapshot, revision, available) = state.withLock { state in
            state.values[key] = newValue.flatMap(value)
            state.revision += 1
            return (state.values, state.revision, state.available)
        }
        guard available else { return }
        Task(name: "Save encrypted Explorer state") {
            do { try await LocalArchive.shared.saveVersioned(LocalRecordEncoding.encode(snapshot), collection: "explorer-state", revision: revision) }
            catch { Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Couldn't save Explorer state: \(error.localizedDescription)") }
        }
    }

    private static func value(_ value: Any) -> Value? {
        if let value = value as? Data { return .data(value) }
        if let value = value as? String { return .string(value) }
        if let value = value as? Bool { return .bool(value) }
        return nil
    }
}
