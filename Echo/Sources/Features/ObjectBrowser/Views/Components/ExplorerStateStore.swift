import Foundation

/// Where the Explorer keeps its own small state (open folders, each dock's section, hidden
/// offline databases). A store of its own, not `UserDefaults.standard`: every write to the
/// standard store wakes every `@AppStorage` view in the app, which made each folder click and
/// dock switch stall a frame. Values saved in the standard store by older builds are still read.
nonisolated enum ExplorerStateStore {
    /// macOS caches suite instances, so looking it up each time is cheap.
    static var defaults: UserDefaults { UserDefaults(suiteName: "dev.echodb.echo.explorer") ?? .standard }

    static func string(forKey key: String) -> String? {
        defaults.string(forKey: key) ?? UserDefaults.standard.string(forKey: key)
    }

    static func data(forKey key: String) -> Data? {
        defaults.data(forKey: key) ?? UserDefaults.standard.data(forKey: key)
    }

    static func bool(forKey key: String) -> Bool? {
        (defaults.object(forKey: key) ?? UserDefaults.standard.object(forKey: key)) as? Bool
    }

    static func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
