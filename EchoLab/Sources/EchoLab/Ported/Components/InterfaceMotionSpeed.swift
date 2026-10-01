// Copied from Echo/Sources/Features/Preferences/Domain/GlobalSettings+Workspace.swift (InterfaceMotionSpeed). Original stays in Echo until the Design Lab is removed.
import CoreGraphics
import Foundation

/// How fast Echo's animations run. Reduce Motion always wins over this.
enum InterfaceMotionSpeed: String, Codable, CaseIterable, Sendable {
    case standard, fast

    var displayName: String {
        switch self {
        case .standard: return "Default"
        case .fast: return "Fast"
        }
    }

    /// Multiplier applied to every animation duration.
    var durationScale: Double {
        switch self {
        case .standard: return 1
        case .fast: return 0.7
        }
    }
}
