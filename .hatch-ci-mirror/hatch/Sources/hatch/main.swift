import Foundation
import HatchCore

let usage = """
hatch: tickets, agents and decisions

Agents use:  next · take · ask · offer · plan · ready · note · search
People use:  init · status · ticket · sync · serve · import-labs · spec · admin
Add --json for machine-readable output, --project <key>, --db <path>.
Run `hatch <command> --help` for a command.
"""

var raw = Array(CommandLine.arguments.dropFirst())
guard let command = raw.first, command != "--help", command != "help" else { print(usage); exit(0) }
let args = Args(raw)
let json = args.flag("json")

do {
    let path = args.option("db") ?? ProcessInfo.processInfo.environment["HATCH_DB"] ?? Home.databasePath
    let store = try HatchStore(path: path)
    var commands = CoreCommands.all
    for (name, handler) in Registry.extra() { commands[name] = handler }
    guard let handler = commands[command] else { throw CLIError("Unknown command '\(command)'.\n\n\(usage)") }
    try handler(Context(store: store, args: args, out: Output(json: json)))
} catch {
    let message = "\(error)"
    if json { print(JSONValue.object(["error": .string(message)]).jsonString(pretty: true)) } else { FileHandle.standardError.write(Data(("hatch: " + message + "\n").utf8)) }
    exit(1)
}
