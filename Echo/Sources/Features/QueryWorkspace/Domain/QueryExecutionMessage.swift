import Foundation
import SwiftUI

struct QueryExecutionMessage: Identifiable, Hashable {
    enum Severity: String, CaseIterable, Hashable {
        case info
        case warning
        case error
        case success
        case debug

        var systemImage: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            case .success: return "checkmark.circle"
            case .debug: return "ladybug"
            }
        }

        var tint: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            case .debug: return .secondary
            }
        }

        var displayName: String {
            switch self {
            case .info: return "Info"
            case .warning: return "Warning"
            case .error: return "Error"
            case .success: return "Success"
            case .debug: return "Debug"
            }
        }
    }

    let id: UUID
    let index: Int
    let category: String
    let message: String
    let timestamp: Date
    let severity: Severity
    let delta: TimeInterval
    let duration: TimeInterval?
    let procedure: String?
    let line: Int?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        index: Int,
        category: String = "Query Execution",
        message: String,
        timestamp: Date = Date(),
        severity: Severity = .info,
        delta: TimeInterval = 0,
        duration: TimeInterval? = nil,
        procedure: String? = nil,
        line: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.index = index
        self.category = category
        self.message = message
        self.timestamp = timestamp
        self.severity = severity
        self.delta = delta
        self.duration = duration
        self.procedure = procedure
        self.line = line
        self.metadata = metadata
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var formattedDelta: String {
        guard delta > 0 else { return "0 ms" }
        return Self.format(delta)
    }

    var formattedDuration: String {
        guard let duration else { return "n/a" }
        return Self.format(duration)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let totalMilliseconds = interval * 1000
        if totalMilliseconds >= 1000 {
            let seconds = totalMilliseconds / 1000
            if seconds >= 60 {
                let minutes = floor(seconds / 60)
                let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60)
                return String(format: "%.0f:%05.2f", minutes, remainingSeconds)
            }
            return String(format: "%.2f s", seconds)
        }
        return String(format: "%.0f ms", totalMilliseconds)
    }
}
