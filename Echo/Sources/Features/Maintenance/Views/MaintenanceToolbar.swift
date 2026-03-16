import SwiftUI

struct MaintenanceToolbar<SectionPicker: View>: View {
    let databases: [String]
    @Binding var selectedDatabase: String?
    @ViewBuilder let sectionPicker: () -> SectionPicker

    var body: some View {
        TabSectionToolbar {
            sectionPicker()
        } controls: {
            HStack(spacing: SpacingTokens.xs) {
                Text("Database:")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                Picker(selection: $selectedDatabase) {
                    ForEach(databases, id: \.self) { db in
                        Text(db).tag(Optional(db))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
        }
    }
}
