import AppKit
import Observation
import SwiftUI

/// Rebuilds Echo Labs from inside Echo Labs (⌘⇧B), shows the progress, and relaunches the
/// new build. It also notices when files changed on disk since this copy was built, so an
/// agent's new round is never invisible.
///
/// It runs `Scripts/open-lab.sh --no-launch`, the same build as the Raycast command, then starts
/// the new copy once this one has quit. A failed build leaves this copy open.
@Observable @MainActor
final class LabBuilder {
    static let shared = LabBuilder()

    enum State: Equatable {
        case idle
        case building(percent: Int?)
        case failed(errors: [String])
        /// Built; waiting for you to press Relaunch (there were picks on the page).
        case ready
    }

    private(set) var state: State = .idle
    /// Files changed on disk since this copy was built.
    private(set) var hasChangesOnDisk = false
    /// Set by the window: true while the current page has picks that aren't sent yet.
    var shouldAskBeforeRelaunch: () -> Bool = { false }

    @ObservationIgnored private var watcher: Task<Void, Never>?

    /// EchoLab/, found from this file's location in the checkout.
    private var packageDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    private var appBundle: URL? { Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil }
    var isBuilding: Bool { if case .building = state { true } else { false } }

    // MARK: Rebuild

    func rebuild() {
        guard !isBuilding else { return }
        state = .building(percent: nil)
        let script = packageDirectory.appending(path: "Scripts/open-lab.sh")
        Task(name: "echolab-rebuild") {
            let result = await Self.runBuild(script: script) { percent in
                Task { @MainActor in if self.isBuilding { self.state = .building(percent: percent) } }
            }
            switch result {
            case .success:
                hasChangesOnDisk = false
                if shouldAskBeforeRelaunch() { state = .ready } else { relaunch() }
            case .failure(let errors):
                state = .failed(errors: errors)
            }
        }
    }

    /// Starts the built bundle once this copy has quit, then quits. Needs the app bundle the
    /// build script writes; a bare `swift run` binary can't relaunch itself.
    func relaunch() {
        guard let bundle = appBundle else {
            state = .failed(errors: ["Echo Labs is not running from its app bundle. Open it with Scripts/open-lab.sh once, then relaunch works."])
            return
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        let command = "unset ECHOLAB_ACTION ECHOLAB_PAGE; while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open -n \"\(bundle.path)\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }

    func dismissFailure() { if case .failed = state { state = .idle } }

    private enum BuildResult: Sendable { case success, failure([String]) }

    /// Runs the script off the main actor, reporting the percentages it prints.
    @concurrent
    private static func runBuild(script: URL, progress: @escaping @Sendable (Int) -> Void) async -> BuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path, "--no-launch"]
        process.environment = ProcessInfo.processInfo.environment.merging(["ECHOLAB_QUIET": "1"]) { _, new in new }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return .failure(["Could not start the build: \(error.localizedDescription)"]) }
        var errors: [String] = []
        var failed = false
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines {
                if let percent = Self.percent(in: line) { progress(percent) }
                if line.hasPrefix("Build failed") { failed = true }
                else if failed || line.contains("error:") { errors.append(line) }
            }
        } catch {}
        process.waitUntilExit()
        if process.terminationStatus == 0 { return .success }
        return .failure(errors.isEmpty ? ["The build failed. Run Scripts/open-lab.sh in a terminal to see why."] : errors)
    }

    nonisolated private static func percent(in line: String) -> Int? {
        guard let match = line.firstMatch(of: /^\s*(\d+)%/) else { return nil }
        return Int(match.1)
    }

    // MARK: Changes on disk

    /// Checks every few seconds whether a source file is newer than this build.
    func startWatching() {
        guard watcher == nil, let executable = Bundle.main.executableURL else { return }
        let sources = [packageDirectory.appending(path: "Sources"), packageDirectory.appending(path: "Package.swift")]
        watcher = Task(name: "echolab-watch-sources") {
            while !Task.isCancelled {
                let changed = await Self.hasNewerFile(in: sources, than: executable)
                if changed != hasChangesOnDisk { hasChangesOnDisk = changed }
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    @concurrent
    private static func hasNewerFile(in roots: [URL], than executable: URL) async -> Bool {
        scan(roots, than: executable)
    }

    nonisolated private static func scan(_ roots: [URL], than executable: URL) -> Bool {
        let manager = FileManager.default
        guard let built = (try? executable.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return false }
        for root in roots {
            let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
            guard let files = manager.enumerator(at: root, includingPropertiesForKeys: keys) else { continue }
            for case let url as URL in files where ["swift", "icns", "png"].contains(url.pathExtension) {
                if let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, date > built { return true }
            }
            if root.pathExtension == "swift",
               let date = (try? root.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, date > built { return true }
        }
        return false
    }
}

/// The toolbar's build status: changes waiting, progress, failure, or Relaunch.
struct LabBuildStatus: View {
    let builder: LabBuilder
    @State private var showsErrors = false

    var body: some View {
        switch builder.state {
        case .idle:
            if builder.hasChangesOnDisk {
                Button { builder.rebuild() } label: {
                    Label("Changes on disk", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Files changed since this copy was built. Rebuild and relaunch (⌘⇧B).")
            }
        case .building(let percent):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(percent.map { "Building \($0)%" } ?? "Building").monospacedDigit()
            }
            .font(.callout).foregroundStyle(.secondary)
        case .failed(let errors):
            Button { showsErrors = true } label: {
                Label("Build failed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.error)
            }
            .popover(isPresented: $showsErrors, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Build failed. This copy is still open.").font(.headline)
                    ScrollView { Text(errors.joined(separator: "\n")).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(width: 520, height: 200)
                    Button("Dismiss") { showsErrors = false; builder.dismissFailure() }
                }
                .padding()
            }
        case .ready:
            Button { builder.relaunch() } label: { Label("Relaunch", systemImage: "arrow.clockwise") }
                .buttonStyle(.borderedProminent)
                .help("The new build is ready. Relaunching keeps everything you have set.")
        }
    }
}
