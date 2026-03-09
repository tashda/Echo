import SwiftUI

struct DiagramPalette {
    let canvasBackground: Color
    let gridLine: Color
    let nodeBackground: Color
    let nodeBorder: Color
    let nodeShadow: Color
    let headerBackground: Color
    let headerBorder: Color
    let headerTitle: Color
    let headerSubtitle: Color
    let columnText: Color
    let columnDetail: Color
    let columnHighlight: Color
    let accent: Color
    let edgeColor: Color
    let overlayBackground: Color
    let overlayBorder: Color
}

struct DiagramColumnAnchor: Identifiable {
    let nodeID: String
    let columnName: String
    let bounds: Anchor<CGRect>

    var id: String { Self.key(nodeID: nodeID, columnName: columnName) }

    static func key(nodeID: String, columnName: String) -> String {
        "\(nodeID.diagramAnchorComponent)#\(columnName.diagramAnchorComponent)"
    }
}

struct DiagramColumnAnchorPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [DiagramColumnAnchor] = []

    static func reduce(value: inout [DiagramColumnAnchor], nextValue: () -> [DiagramColumnAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

extension String {
    var diagramAnchorComponent: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
