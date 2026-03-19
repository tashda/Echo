import SwiftUI

struct ActivityMonitorToolbar<SectionPicker: View>: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @ViewBuilder let sectionPicker: () -> SectionPicker

    var body: some View {
        TabSectionToolbar {
            sectionPicker()
        }
    }
}
