import AppKit
import SwiftUI

/// What `EchoLab/Scripts/verify-round.py` asks an app to capture. The script writes it to a file
/// and launches Echo Labs or Echo with `ECHO_CONFORMANCE=<that file>`.
public struct ConformanceRequest: Codable, Sendable {
    /// One state of the specimen to capture (resting, hovered…): the screenshot is taken `settle`
    /// seconds after it is shown, and parts are watched until `observe` seconds (for timelines).
    public struct State: Codable, Sendable {
        public var id: String
        public var settle: Double
        public var observe: Double

        public init(id: String, settle: Double, observe: Double) {
            self.id = id
            self.settle = settle
            self.observe = observe
        }
    }

    public var page: String
    /// The folder the shots go to.
    public var out: String
    /// `light` and/or `dark`.
    public var appearances: [String]
    /// The states and size; Echo Labs fills them in from the round, Echo reads them from the
    /// contract the reference wrote.
    public var states: [State]?
    public var width: Double?
    public var height: Double?
    /// The owner's picks for the round (Echo Labs only), from `lab-state.json`.
    public var picks: [String: String]?

    public static let environmentKey = "ECHO_CONFORMANCE"

    /// The request this process was launched with, if any.
    public static func load() -> ConformanceRequest? {
        guard let path = ProcessInfo.processInfo.environment[environmentKey],
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? JSONDecoder().decode(ConformanceRequest.self, from: data)
    }
}

/// One captured shot: the screenshot's file name and every tagged part's frame at that moment.
public struct ConformanceShot: Codable, Sendable {
    public var state: String
    public var appearance: String
    public var width: Double
    public var height: Double
    /// Pixels per point in the screenshot.
    public var scale: Double
    public var image: String
    /// Whether the app was the active app when the screenshot was taken (a capture launched from
    /// a shell usually is not; both sides should agree).
    public var appWasActive: Bool
    public var parts: [String: ConformanceRecorder.Part]
}

/// Shows a specimen in a bare window for each state and appearance, screenshots the window and
/// records its tagged parts. Echo Labs and Echo both capture through this, so the two sides are
/// measured the same way.
@MainActor
public enum ConformanceCapture {
    public enum Failure: Error {
        case screenshotFailed(Int32)
    }

    /// Captures every state in every appearance and writes `capture.json` (the shots) next to the
    /// screenshots. `specimen` builds the view for a state id.
    public static func run(request: ConformanceRequest, states: [ConformanceRequest.State], size: CGSize,
                           specimen: (String) -> AnyView) async throws -> [ConformanceShot] {
        let out = URL(fileURLWithPath: request.out, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        // The app's own windows are put away, so the specimen is drawn the same way on both sides.
        NSApp.windows.forEach { $0.orderOut(nil) }
        var shots: [ConformanceShot] = []
        for appearance in request.appearances {
            for state in states {
                shots.append(try await capture(state: state, appearance: appearance, size: size, out: out,
                                               specimen: specimen(state.id)))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(shots).write(to: out.appendingPathComponent("capture.json"))
        return shots
    }

    private static func capture(state: ConformanceRequest.State, appearance: String, size: CGSize, out: URL,
                                specimen: AnyView) async throws -> ConformanceShot {
        let recorder = ConformanceRecorder()
        let root = specimen
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named(ConformanceRecorder.space))
            .environment(\.conformanceRecorder, recorder)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // The app's appearance too, not only the window's: glass draws its content partly from
        // the app's, and neither the system setting nor Echo's own Appearance setting may leak in.
        let shotAppearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        let previousAppearance = NSApp.appearance
        NSApp.appearance = shotAppearance
        defer { NSApp.appearance = previousAppearance }
        window.appearance = shotAppearance
        window.contentView = NSHostingView(rootView: root)
        window.level = .floating
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.maxX - size.width - SpacingTokens.xl, y: visible.maxY - size.height - SpacingTokens.xl))
        }
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        try await Task.sleep(for: .seconds(state.settle))
        let image = "\(state.id)-\(appearance).png"
        let appWasActive = NSApp.isActive
        try await screenshot(windowNumber: window.windowNumber, to: out.appendingPathComponent(image))
        var parts = recorder.parts
        if state.observe > state.settle {
            try await Task.sleep(for: .seconds(state.observe - state.settle))
        }
        // Frames as they were in the screenshot; timelines as watched to the end.
        for (name, part) in recorder.parts {
            if parts[name] == nil { parts[name] = part }
            parts[name]?.appearedAt = part.appearedAt
            parts[name]?.disappearedAt = part.disappearedAt
        }
        return ConformanceShot(state: state.id, appearance: appearance, width: size.width, height: size.height,
                               scale: window.backingScaleFactor, image: image, appWasActive: appWasActive, parts: parts)
    }

    /// The window as the window server composites it, so glass and AppKit views are drawn.
    private static func screenshot(windowNumber: Int, to url: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l\(windowNumber)", url.path]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Failure.screenshotFailed(finished.terminationStatus))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
