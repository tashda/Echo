import SwiftUI

/// Round 15: where the notification history opens, now that it isn't a popover.
enum LabNoticeCenterStyle: String, CaseIterable, Identifiable {
    case unfold = "A · Unfold from the stack"
    case drawer = "B · Drawer column"
    case tab = "C · Notifications tab"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .unfold: "The bell unfolds the toast stack, in place, into a taller glass panel the toasts' width. Notifications always live in one corner."
        case .drawer: "The history takes the inspector's column: a full-height card on the canvas with room for long text. The bell switches the column between the two."
        case .tab: "The history opens as a tab: the list on the left, the whole message on the right, selectable, with Copy and Open Tab."
        }
    }
}

/// Where the toasts' top edge sits.
enum LabToastTop: String, CaseIterable, Identifiable {
    case belowToolbar = "Below the toolbar"
    case belowTabBar = "Below the tab bar"
    var id: String { rawValue }
}

enum LabRound15NoticeMetrics {
    static let windowWidth: CGFloat = 1_000
    static let windowHeight: CGFloat = 560
    static let treeWidth: CGFloat = 200
    static let inspectorWidth: CGFloat = 260
    static let toastWidth: CGFloat = LayoutTokens.FloatingSurface.mediumWidth
    static let panelMaxHeight: CGFloat = 420
    static let historyListWidth: CGFloat = 300
}

struct LabNotice: Identifiable, Equatable {
    enum Kind { case success, error, info }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let server: String
    let time: String
    var count = 1
    var canOpenTab = false

    var symbol: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .success: ColorTokens.Status.success
        case .error: ColorTokens.Status.error
        case .info: ColorTokens.Text.secondary
        }
    }

    static let samples: [LabNotice] = [
        LabNotice(kind: .success, title: "Connected to Test MSSQL", detail: "mssql25 · SQL Server 2025 · 14 ms", server: "Test MSSQL", time: "now"),
        LabNotice(kind: .error, title: "Query 3 failed", detail: "Msg 207, Level 16, State 1, Line 3\nInvalid column name 'hire_dat'. Did you mean 'hire_date'? The statement has been terminated. Batch 2 of 4 ran for 0.8 s before the error; batches 3 and 4 were not run.", server: "Test MSSQL", time: "1 min ago", canOpenTab: true),
        LabNotice(kind: .success, title: "Backup completed for employees", detail: "Written to /var/opt/mssql/backup/employees_2026-09-30.bak · 1.4 GB in 42 s", server: "Test MSSQL", time: "12 min ago"),
        LabNotice(kind: .info, title: "Switched to sales", detail: "Query 2 now runs against sales.", server: "tippr", time: "9 h ago", canOpenTab: true),
    ]
}

/// The toasts and the history, and which of them is open.
@MainActor @Observable
final class LabNoticeCenter {
    var toasts: [LabNotice] = []
    var history: [LabNotice] = LabNotice.samples
    var hoveredToast: UUID?
    var expandedItem: UUID?
    var isOpen = false

    private var nextSample = 0

    func post() {
        let sample = LabNotice.samples[nextSample % LabNotice.samples.count]
        nextSample += 1
        let notice = LabNotice(kind: sample.kind, title: sample.title, detail: sample.detail, server: sample.server, time: "now", canOpenTab: sample.canOpenTab)
        toasts.insert(notice, at: 0)
        history.insert(notice, at: 0)
        if toasts.count > 3 { toasts.removeLast() }
        guard notice.kind != .error else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            while self?.hoveredToast == notice.id { try? await Task.sleep(for: .milliseconds(300)) }
            self?.toasts.removeAll { $0.id == notice.id }
        }
    }

    func repeatLatest() {
        guard !toasts.isEmpty else { return post() }
        toasts[0].count += 1
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }
}
