import Foundation
import HatchCore

struct Context {
    let store: HatchStore
    let args: Args
    let out: Output

    /// `--project key`, else HATCH_PROJECT, else the only project in the database.
    func project() throws -> Project {
        let projects = try store.projects()
        if let key = args.option("project") ?? ProcessInfo.processInfo.environment["HATCH_PROJECT"] {
            guard let p = projects.first(where: { $0.key == key }) else { throw CLIError("No project '\(key)'. Known: \(projects.map(\.key).joined(separator: ", "))") }
            return p
        }
        guard projects.count == 1, let only = projects.first else {
            throw CLIError(projects.isEmpty ? "No project yet. Run: hatch init --config .hatch/project.json" : "More than one project; pass --project <key>.")
        }
        return only
    }

    func ticket(_ ref: String?) throws -> Ticket {
        guard let ref, !ref.isEmpty else { throw CLIError("Which ticket? Pass a number such as #151.") }
        return try store.resolve(ref)
    }

    func actor(default d: Actor = .agent) throws -> Actor {
        guard let a = args.option("as") else { return d }
        guard let actor = Actor(rawValue: a) else { throw CLIError("--as must be owner, agent or hatch.") }
        return actor
    }
}
