import Foundation
import SwiftUI

/// Collects what a conformance capture measures: the frame of every tagged part of a specimen,
/// and when each part appeared and went away. Echo Labs and Echo record the same way, so an
/// accepted round and the code built from it can be compared (see `EchoLab/Scripts/verify-round.py`).
@MainActor
public final class ConformanceRecorder {
    /// One tagged part: where it is (in the specimen's coordinate space) and its timeline, in
    /// seconds from the moment the specimen was shown.
    public struct Part: Codable, Sendable, Equatable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var appearedAt: Double?
        public var disappearedAt: Double?
    }

    /// The coordinate space every tag measures in; the capture puts it at the specimen's root.
    public nonisolated static let space = "conformance.specimen"

    private let start = Date()
    public private(set) var parts: [String: Part] = [:]

    public init() {}

    func record(_ name: String, frame: CGRect) {
        var part = parts[name] ?? Part(x: 0, y: 0, width: 0, height: 0)
        part.x = frame.minX
        part.y = frame.minY
        part.width = frame.width
        part.height = frame.height
        parts[name] = part
    }

    func appeared(_ name: String) {
        var part = parts[name] ?? Part(x: 0, y: 0, width: 0, height: 0)
        if part.appearedAt == nil { part.appearedAt = elapsed }
        part.disappearedAt = nil
        parts[name] = part
    }

    func disappeared(_ name: String) {
        parts[name]?.disappearedAt = elapsed
    }

    private var elapsed: Double { (Date().timeIntervalSince(start) * 1000).rounded() / 1000 }
}

extension EnvironmentValues {
    /// Set only while a conformance capture runs; tags do nothing without it.
    @Entry public var conformanceRecorder: ConformanceRecorder?
}
