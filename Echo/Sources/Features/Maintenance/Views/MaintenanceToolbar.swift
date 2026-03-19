import SwiftUI

struct MaintenanceToolbar<SectionPicker: View>: View {
    @ViewBuilder let sectionPicker: () -> SectionPicker

    var body: some View {
        TabSectionToolbar {
            sectionPicker()
        }
    }
}
