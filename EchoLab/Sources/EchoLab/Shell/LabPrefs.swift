import Foundation

/// Everything you set in Echo Labs is remembered between launches and when you navigate away.
/// Small settings go through here (UserDefaults, keys prefixed `lab.`); your feedback, comments
/// and round picks live in the repo's `EchoLab/State/lab-state.json` so agents can read them.
enum LabPrefs {
    static func load<T: Decodable>(_ key: String, default value: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: "lab." + key),
              let stored = try? JSONDecoder().decode(T.self, from: data) else { return value }
        return stored
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: "lab." + key)
    }
}
