import SwiftUI

struct InspectorLibrarySpecimen: View {
    @State private var section = "Details"
    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Picker("Inspector content", selection: $section) {
                ForEach(["Details", "Bookmarks", "History"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            switch section {
            case "Bookmarks": LabRTBookmarksToday()
            case "History": LabRHAcceptedList()
            default: LabInspectorColumn(look: .groupedBoxes)
            }
        }.frame(width: LayoutTokens.Inspector.idealWidth)
    }
}
