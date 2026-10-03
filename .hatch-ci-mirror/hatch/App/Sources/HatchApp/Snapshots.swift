import SwiftUI
import AppKit
import HatchCore

/// `Hatch --snapshots <folder>` opens the window on made-up data, saves a PNG of each main screen in light and dark, and quits.
/// CI uses it so the screens can be looked at without a person running the app. It never touches the real database.
enum Snapshots {
    static var folder: URL? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--snapshots"), i + 1 < a.count else { return nil }
        return URL(fileURLWithPath: a[i + 1], isDirectory: true)
    }

    @MainActor static func demoState() -> AppState {
        let store = try! HatchStore.inMemory()
        let p = try! store.upsertProject(key: "echo", name: "Echo")
        let rows: [(TicketType, Status, String, String)] = [
            (.proposal, .yourCall, "Toast spacing and corner radius", "connections"),
            (.proposal, .preparing, "Query tab empty state", "editor"),
            (.sketch, .yourCall, "Sidebar density options", "sidebar"),
            (.bug, .toVerify, "Results grid loses scroll position after sort", "results"),
            (.bug, .building, "Connection test hangs on bad host", "connections"),
            (.tweak, .ready, "Rename Run to Execute in the toolbar", "editor"),
            (.question, .needsAnswers, "Should tabs restore after a crash?", "editor"),
            (.theme, .building, "Polish the Connections area", "connections"),
            (.tweak, .merged, "Align icon sizes in the inspector", "inspector"),
            (.bug, .blocked, "Export to CSV drops the last row", "results"),
            (.proposal, .accepted, "Command palette layout", "palette"),
            (.question, .draft, "Do we need a dark-only mode?", "settings"),
        ]
        for (i, r) in rows.enumerated() {
            _ = try? store.createTicket(projectId: p.id, type: r.0, title: r.2, body: "Made-up example text for \(r.2).",
                                        area: r.3, ghNumber: 140 + i, status: r.1)
        }
        let paths = AppPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("hatch-snapshots-\(getpid())"))
        return AppState(store: store, paths: paths)
    }

    @MainActor static func run(state: AppState, into folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let first = (try? state.store.tickets(TicketFilter()))?.first?.id
        var routes: [(String, Route)] = [("desk", .desk), ("tickets", .tickets), ("board", .board), ("previews", .previews),
                                         ("specs", .specs), ("decisions", .decisions), ("agents", .agents), ("log", .log),
                                         ("project", .projects), ("new-ticket", .newTicket)]
        if let first { routes.insert(("ticket", .ticket(first)), at: 3) }
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        if let w = NSApp.windows.first(where: { $0.isVisible }) { w.setContentSize(NSSize(width: 1360, height: 860)); w.center() }
        try? await Task.sleep(nanoseconds: 800_000_000)
        for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            for (name, route) in routes {
                state.route = route
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard let window = NSApp.windows.first(where: { $0.isVisible }), let view = window.contentView?.superview ?? window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("\(name)-\(mode).png"))
                }
            }
        }
        NSApp.terminate(nil)
    }
}
