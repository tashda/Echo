import AppKit
import Testing
@testable import Echo

@Suite("Sidebar Section Tabs")
struct SidebarSectionTabsTests {
    @MainActor
    @Test("Uses the native platform navigation selector")
    func nativeControlConfiguration() {
        let control = SidebarSectionTabsControl.makeControl(target: nil, action: nil)

        #expect(control.trackingMode == .selectOne)
        #expect(control.segmentStyle == .automatic)
        #expect(control.borderShape == .capsule)
        #expect(control.segmentDistribution == .fillEqually)
        #expect(control.controlSize == .large)
        #expect(control.segmentCount == SidebarMenu.NavSection.allCases.count)
        #expect(control.contentHuggingPriority(for: .vertical) == .defaultLow)
        #expect(control.contentCompressionResistancePriority(for: .vertical) == .defaultLow)

        if #available(macOS 27.0, *) {
            #expect(control.role == .tabs)
        }
    }
}
