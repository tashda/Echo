import SwiftUI
import AppKit

struct MySQLActivitySectionPicker: NSViewRepresentable {
    typealias Section = MySQLActivityMonitorView.MySQLActivitySection

    @Binding var selection: Section

    private static let allSections = Section.allCases

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = Self.allSections.count
        control.segmentStyle = .automatic
        control.trackingMode = .selectOne
        control.target = context.coordinator
        control.action = #selector(Coordinator.segmentChanged(_:))

        for (index, section) in Self.allSections.enumerated() {
            control.setLabel(section.rawValue, forSegment: index)
            control.setWidth(0, forSegment: index)
        }

        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        if let selectedIndex = Self.allSections.firstIndex(of: selection) {
            control.selectedSegment = selectedIndex
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    final class Coordinator: NSObject {
        var selection: Binding<Section>

        init(selection: Binding<Section>) {
            self.selection = selection
        }

        @MainActor @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0, index < MySQLActivitySectionPicker.allSections.count else { return }
            selection.wrappedValue = MySQLActivitySectionPicker.allSections[index]
        }
    }
}
