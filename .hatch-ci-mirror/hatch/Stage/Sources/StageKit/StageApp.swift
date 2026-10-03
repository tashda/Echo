import SwiftUI
import AppKit
import StageCore

/// What the Stage was launched with.
///
///     HatchStageToast --demo                       runs on its own with the in-memory data source
///     HatchStageToast --ticket 151                 talks to Hatch's local API (HatchAPIStageDataSource)
///     HatchStageToast --manifest /path/m.json      uses that manifest instead of the one compiled into the round
///     HatchStageToast --home /path/to/Hatch        Hatch's support directory (token and port), as the launching app passes it
///     HatchStageToast --check                      headless: draws every specimen in every scenario, prints JSON, exits 0 or 1
public struct StageLaunchOptions: Equatable {
    public var demo: Bool = false
    public var ticket: String? = nil
    public var manifestPath: String? = nil
    public var home: String? = nil
    public var check: Bool = false

    public init() {}

    public static func parse(_ arguments: [String]) -> StageLaunchOptions {
        var o = StageLaunchOptions()
        var i = 0
        while i < arguments.count {
            let a = arguments[i]
            if a == "--demo" {
                o.demo = true
            } else if a == "--ticket", i + 1 < arguments.count {
                o.ticket = arguments[i + 1]
                i += 1
            } else if a == "--manifest", i + 1 < arguments.count {
                o.manifestPath = arguments[i + 1]
                i += 1
            } else if a == "--home", i + 1 < arguments.count {
                o.home = arguments[i + 1]
                i += 1
            } else if a == "--check" {
                o.check = true
            }
            i += 1
        }
        return o
    }
}

/// The entry point a round's executable calls from `main.swift`:
///
///     StageApp.run(provider: MyProvider(), manifest: MyManifest.load())
@MainActor
public enum StageApp {
    private static var delegate: StageAppDelegate? = nil

    /// Opens the Stage window and runs until it is closed.
    /// - Parameters:
    ///   - provider: the round's specimens.
    ///   - manifest: the Proposal as compiled into the round; `--manifest <path>` overrides it.
    ///   - dataSource: where picks go. When `nil`: `--demo` or no `--ticket` uses the in-memory source, `--ticket` uses Hatch.
    public static func run(provider: any SpecimenProvider, manifest: StageManifest,
                           dataSource: StageDataSource? = nil, arguments: [String] = CommandLine.arguments) {
        let options = StageLaunchOptions.parse(Array(arguments.dropFirst()))
        var effective = manifest
        if let path = options.manifestPath {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                effective = try StageManifest.parse(data: data)
            } catch {
                FileHandle.standardError.write(Data("Could not read the manifest at \(path): \(error)\n".utf8))
            }
        }
        if options.check {
            // Decision S6: Hatch runs the built Stage headless before the ticket becomes Your call.
            exit(StageSelfCheck.run(provider: provider, manifest: effective))
        }
        let source: StageDataSource
        if let given = dataSource {
            source = given
        } else if !options.demo, let ticket = options.ticket {
            if let home = options.home, !home.isEmpty {
                source = HatchAPIStageDataSource(ticket: ticket, home: URL(fileURLWithPath: home, isDirectory: true))
            } else {
                source = HatchAPIStageDataSource(ticket: ticket)
            }
        } else {
            source = InMemoryStageDataSource(manifest: effective)
        }
        let model = StageModel(manifest: effective, provider: provider, dataSource: source)
        model.captureView = { StageSnapshot.jpegOfFrontStageWindow() }
        let d = StageAppDelegate(model: model, title: windowTitle(effective, options))
        delegate = d
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = d
        app.run()
    }

    private static func windowTitle(_ manifest: StageManifest, _ options: StageLaunchOptions) -> String {
        let name = manifest.title.isEmpty ? "Proposal" : manifest.title
        return "Hatch Stage · \(name) · rev \(manifest.revision)"
    }
}

/// Set by the task that tells Hatch the Stage closed; the delegate waits for it for a moment.
private final class DoneFlag: @unchecked Sendable {
    var value = false
}

@MainActor
final class StageAppDelegate: NSObject, NSApplicationDelegate {
    private let model: StageModel
    private let title: String
    private var window: NSWindow? = nil

    init(model: StageModel, title: String) {
        self.model = model
        self.title = title
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        let hosting = NSHostingView(rootView: StageView(model: model))
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.title = title
        w.contentView = hosting
        w.contentMinSize = NSSize(width: 760, height: 540)
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Tells Hatch this Stage was closed on purpose, so it can tell that from a crash (decision S7). Gives the call half a second.
    func applicationWillTerminate(_ notification: Notification) {
        let flag = DoneFlag()
        let model = self.model
        Task { @MainActor in
            await model.announceClosed()
            flag.value = true
        }
        let deadline = Date().addingTimeInterval(0.5)
        while !flag.value && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    /// A programmatic app has no menu bar unless it makes one. Quit and the Edit items (so Paste works in notes) are enough.
    private func installMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Hatch Stage", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
