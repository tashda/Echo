import Foundation
import HatchCore

/// Setting a project up from the files in its app repo (decisions L1 and L2).
public enum ProjectBootstrap {
    /// `<projectRoot>/.hatch/project.json`
    public static func configURL(projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent(".hatch/project.json")
    }

    /// Reads `.hatch/project.json` and registers the project and its repos in the store. Safe to repeat: it updates what is there.
    /// `key` defaults to a slug of the project name (`Echo` becomes `echo`). The app repo's local path is set to `projectRoot`
    /// when the file does not give one, because that is where Hatch found it.
    @discardableResult
    public static func load(projectRoot: URL, store: HatchStore, key: String? = nil) throws -> Project {
        let url = configURL(projectRoot: projectRoot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StoreError.notFound("\(url.path) (set the project up in Settings, or write .hatch/project.json)")
        }
        let config: ProjectConfig
        do { config = try ProjectConfig.load(from: url) } catch {
            throw StoreError.invalid("\(url.path) is not a valid project file: \(error)")
        }
        let projectKey = key ?? HatchStore.slug(config.name)
        guard !projectKey.isEmpty else { throw StoreError.invalid("The project needs a name.") }
        let project = try store.upsertProject(key: projectKey, name: config.name, config: config)
        if var app = config.repo(.app), app.localPath == nil {
            app.localPath = projectRoot.path
            try store.upsertRepo(projectId: project.id, repo: app)
        }
        return project
    }

    // MARK: Area suggestions

    private static let skipped: Set<String> = [".git", ".build", ".swiftpm", ".hatch", ".github", ".claude", "build", "DerivedData",
                                                "node_modules", "Pods", "Carthage", "docs", "Docs", "Scripts", "scripts", "Tests", "Resources"]

    /// Proposes one area per feature folder as the starting point for the agent-drafted area index (L2); the owner then
    /// corrects it. Looks for a `Features` folder (Echo: `Echo/Sources/Features/<Name>/**`); when there is none it falls
    /// back to the Swift package targets under `Sources/`, then to the top-level folders. Empty folders are ignored.
    public static func suggestAreas(repoRoot: URL) -> [AreaConfig] {
        var parents = featureFolders(in: repoRoot)
        if parents.isEmpty {
            let sources = repoRoot.appendingPathComponent("Sources")
            parents = [FileManager.default.fileExists(atPath: sources.path) ? "Sources" : ""]
        }
        var areas: [AreaConfig] = []
        var usedPrefixes = Set<String>()
        for parent in parents {
            let dir = parent.isEmpty ? repoRoot : repoRoot.appendingPathComponent(parent)
            for name in subfolders(dir) {
                guard hasFiles(dir.appendingPathComponent(name)) else { continue }
                let rel = parent.isEmpty ? name : parent + "/" + name
                if areas.contains(where: { $0.paths == [rel + "/**"] }) { continue }
                let words = splitWords(name)
                areas.append(AreaConfig(name: words.joined(separator: " "), paths: [rel + "/**"], specPrefix: uniquePrefix(words, used: &usedPrefixes)))
            }
        }
        return areas.sorted { $0.name < $1.name }
    }

    /// Relative paths of folders named `Features`, up to five levels down, without descending into build output.
    static func featureFolders(in root: URL) -> [String] {
        var found: [String] = []
        func walk(_ rel: String, depth: Int) {
            let dir = rel.isEmpty ? root : root.appendingPathComponent(rel)
            for name in subfolders(dir) {
                let childRel = rel.isEmpty ? name : rel + "/" + name
                if name == "Features" { found.append(childRel); continue }
                if depth < 4 { walk(childRel, depth: depth + 1) }
            }
        }
        walk("", depth: 0)
        return found.sorted()
    }

    static func subfolders(_ dir: URL) -> [String] {
        let fm = FileManager.default
        return ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).sorted().filter { name in
            guard !name.hasPrefix("."), !skipped.contains(name) else { return false }
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: dir.appendingPathComponent(name).path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    static func hasFiles(_ dir: URL) -> Bool {
        guard let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return false }
        for case let url as URL in walker where !url.lastPathComponent.hasPrefix(".") && (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { return true }
        return false
    }

    /// `ObjectBrowser` to ["Object", "Browser"]; `SQLServer` to ["SQL", "Server"]; `data_migration` to ["Data", "Migration"].
    static func splitWords(_ name: String) -> [String] {
        var words: [String] = [], current = ""
        let chars = Array(name)
        for (i, c) in chars.enumerated() {
            if c == "_" || c == "-" || c == " " { if !current.isEmpty { words.append(current); current = "" }; continue }
            if !current.isEmpty, c.isUppercase {
                let prev = chars[i - 1]
                let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                if prev.isLowercase || prev.isNumber || (prev.isUppercase && (next?.isLowercase ?? false)) { words.append(current); current = "" }
            }
            current.append(c)
        }
        if !current.isEmpty { words.append(current) }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    /// Initials for several words (`ObjectBrowser` is `OB`); for one word its first letter and next consonants (`Editor` is `EDT`).
    static func uniquePrefix(_ words: [String], used: inout Set<String>) -> String {
        var base: String
        if words.count >= 2 {
            base = String(words.prefix(4).compactMap { $0.first }).uppercased()
        } else {
            let w = (words.first ?? "X").uppercased()
            if w.count <= 3 { base = w } else {
                let vowels = Set("AEIOU")
                base = String(w.first!) + String(w.dropFirst().filter { !vowels.contains($0) }.prefix(2))
                if base.count < 3 { base = String(w.prefix(3)) }
            }
        }
        var candidate = base, n = 2
        while used.contains(candidate) { candidate = base + String(n); n += 1 }
        used.insert(candidate)
        return candidate
    }
}
