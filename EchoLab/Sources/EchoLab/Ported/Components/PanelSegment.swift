// Copied from Echo/Sources/Features/AppHost/Domain/BottomPanelState.swift (PanelSegment). Original stays in Echo until the Design Lab is removed.
import Foundation
import SwiftUI

/// Defines the content segments available in the bottom panel.
enum PanelSegment: String, Hashable, Identifiable, CaseIterable {
    case results
    case textResults
    case verticalResults
    case statistics
    case messages
    case executionPlan
    case jsonInspector
    case liveData
    case spatial
    case tuning
    case policyManagement
    case history
    var id: String { rawValue }

    var label: String {
        switch self {
        case .results: return "Results"
        case .textResults: return "Text"
        case .verticalResults: return "Vertical"
        case .statistics: return "Statistics"
        case .messages: return "Messages"
        case .executionPlan: return "Execution Plan"
        case .jsonInspector: return "JSON Inspector"
        case .liveData: return "Live Data"
        case .spatial: return "Spatial"
        case .tuning: return "Tuning"
        case .policyManagement: return "Policy Management"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .results: return "tablecells"
        case .textResults: return "doc.plaintext"
        case .verticalResults: return "list.bullet.rectangle.portrait"
        case .statistics: return "chart.bar.xaxis"
        case .messages: return "text.bubble"
        case .executionPlan: return "chart.bar.doc.horizontal"
        case .jsonInspector: return "curlybraces"
        case .liveData: return "waveform.path.ecg"
        case .spatial: return "map"
        case .tuning: return "wand.and.stars"
        case .policyManagement: return "checkmark.seal"
        case .history: return "clock.arrow.circlepath"
        }
    }
}
