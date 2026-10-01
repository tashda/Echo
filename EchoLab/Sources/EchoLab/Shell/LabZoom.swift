import Observation
import SwiftUI

/// How large the previews on round pages and decided pages are drawn. 100% is the size Echo draws
/// them. The toolbar's zoom buttons and ⌘+, ⌘- and ⌘0 change it, and it is remembered between
/// launches. Zooming gives each preview more room (fewer exhibits side by side) instead of
/// cropping it; a preview that still does not fit is scaled down and says so.
@Observable @MainActor
final class LabZoom {
    static let shared = LabZoom()

    static let steps: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]

    var level: Double = LabPrefs.load("zoom", default: 1.0) {
        didSet { LabPrefs.save(level, key: "zoom") }
    }

    var percent: String { "\(Int((level * 100).rounded()))%" }
    var canZoomIn: Bool { level < Self.steps.last! }
    var canZoomOut: Bool { level > Self.steps.first! }

    func zoomIn() { if let next = Self.steps.first(where: { $0 > level + 0.001 }) { level = next } }
    func zoomOut() { if let previous = Self.steps.last(where: { $0 < level - 0.001 }) { level = previous } }
    func reset() { level = 1 }
}

/// The toolbar's zoom control: smaller, the level (click to reset), larger.
struct LabZoomControls: View {
    let zoom: LabZoom

    var body: some View {
        ControlGroup {
            Button("Zoom Out", systemImage: "minus.magnifyingglass") { zoom.zoomOut() }
                .disabled(!zoom.canZoomOut)
            Button(zoom.percent) { zoom.reset() }
                .monospacedDigit()
            Button("Zoom In", systemImage: "plus.magnifyingglass") { zoom.zoomIn() }
                .disabled(!zoom.canZoomIn)
        }
        .help("Preview size. 100% is the size Echo draws it. ⌘- and ⌘+; ⌘0 goes back to actual size")
    }
}
