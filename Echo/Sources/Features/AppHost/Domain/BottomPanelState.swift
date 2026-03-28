import Foundation
import SwiftUI

/// Defines the content segments available in the bottom panel.
enum PanelSegment: String, Hashable, Identifiable, CaseIterable {
    case results
    case textResults
    case verticalResults
    case messages
    case executionPlan
    case jsonInspector
    case liveData
    case spatial
    case tuning
    case policyManagement
    var id: String { rawValue }

    var label: String {
        switch self {
        case .results: return "Results"
        case .textResults: return "Text"
        case .verticalResults: return "Vertical"
        case .messages: return "Messages"
        case .executionPlan: return "Execution Plan"
        case .jsonInspector: return "JSON Inspector"
        case .liveData: return "Live Data"
        case .spatial: return "Spatial"
        case .tuning: return "Tuning"
        case .policyManagement: return "Policy Management"
        }
    }

    var icon: String {
        switch self {
        case .results: return "tablecells"
        case .textResults: return "doc.plaintext"
        case .verticalResults: return "list.bullet.rectangle.portrait"
        case .messages: return "text.bubble"
        case .executionPlan: return "chart.bar.doc.horizontal"
        case .jsonInspector: return "curlybraces"
        case .liveData: return "waveform.path.ecg"
        case .spatial: return "map"
        case .tuning: return "wand.and.stars"
        case .policyManagement: return "checkmark.seal"
        }
    }
}

/// Per-tab state for the universal bottom panel.
@Observable
final class BottomPanelState {
    var isOpen: Bool
    var splitRatio: CGFloat
    var selectedSegment: PanelSegment
    var availableSegments: [PanelSegment]
    var messages: [QueryExecutionMessage] = []

    @ObservationIgnored private var lastMessageTimestamp: Date?

    init(
        isOpen: Bool = false,
        splitRatio: CGFloat = 0.5,
        selectedSegment: PanelSegment = .messages,
        availableSegments: [PanelSegment] = [.messages]
    ) {
        self.isOpen = isOpen
        self.splitRatio = splitRatio
        self.selectedSegment = selectedSegment
        self.availableSegments = availableSegments
    }

    func appendMessage(
        _ text: String,
        severity: QueryExecutionMessage.Severity = .info,
        category: String = "Operation",
        duration: TimeInterval? = nil,
        procedure: String? = nil,
        line: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        let now = Date()
        let delta = lastMessageTimestamp.map { now.timeIntervalSince($0) } ?? 0
        let message = QueryExecutionMessage(
            index: messages.count + 1,
            category: category,
            message: text,
            timestamp: now,
            severity: severity,
            delta: delta,
            duration: duration,
            procedure: procedure,
            line: line,
            metadata: metadata
        )
        messages.append(message)
        lastMessageTimestamp = now
    }

    func clearMessages() {
        messages.removeAll()
        lastMessageTimestamp = nil
    }

    static func forQueryTab() -> BottomPanelState {
        BottomPanelState(
            isOpen: false,
            splitRatio: 0.5,
            selectedSegment: .results,
            availableSegments: [.results, .textResults, .verticalResults, .messages, .spatial, .executionPlan, .tuning]
        )
    }

    static func forMaintenanceTab() -> BottomPanelState {
        BottomPanelState(
            isOpen: false,
            splitRatio: 0.65,
            selectedSegment: .messages,
            availableSegments: [.messages, .policyManagement]
        )
    }

    static func forExtendedEventsTab() -> BottomPanelState {
        BottomPanelState(
            isOpen: false,
            splitRatio: 0.55,
            selectedSegment: .liveData,
            availableSegments: [.liveData, .messages]
        )
    }

    static func forGenericTab() -> BottomPanelState {
        BottomPanelState(
            isOpen: false,
            splitRatio: 0.65,
            selectedSegment: .messages,
            availableSegments: [.messages]
        )
    }
}
