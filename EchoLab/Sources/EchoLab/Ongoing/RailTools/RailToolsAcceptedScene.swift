import SwiftUI

/// Round 39 RT2: the tree stays; Details and saved SQL share the trailing column.
struct RailToolsAcceptedScene: View {
    @State private var selectedServer: String? = LabServer.samples.first?.id
    @State var section = "History"
    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            WindowRailSpecimen(selected: $selectedServer)
            LabSHCard(server: .production, look: .today, rowLimit: 6)
                .frame(width: 220).frame(maxHeight: .infinity, alignment: .top)
            LabWKEditor().workspaceCard()
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
        }.padding(SpacingTokens.sm).background(ColorTokens.Workspace.canvas)
    }
}
