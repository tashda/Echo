import Foundation

// MARK: - Window Value

struct SubscriptionEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let subscriptionName: String?

    var isEditing: Bool { subscriptionName != nil }
}

// MARK: - Pages

enum SubscriptionEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case options
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .options: "Options"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "doc.text"
        case .options: "gearshape"
        case .sql: "scroll"
        }
    }
}

// MARK: - Synchronous Commit

enum SubscriptionSynchronousCommit: String, CaseIterable, Identifiable {
    case off
    case local
    case remoteWrite = "remote_write"
    case remoteApply = "remote_apply"
    case on

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "off"
        case .local: "local"
        case .remoteWrite: "remote_write"
        case .remoteApply: "remote_apply"
        case .on: "on"
        }
    }
}
