import SwiftUI
import Foundation

extension ForeignKeyEditorSheet {
    var referenceSection: some View {
        Section {
            TextField("Referenced Columns", text: $draft.referencedColumnsInput)
        } header: {
            Text("References")
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Separate names with commas in the same order as local columns.")
                if draft.referencedColumnsMismatch {
                    Text("Column counts do not match.")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    var actionsSection: some View {
        Section {
            TextField("ON UPDATE", text: $draft.onUpdate)
            TextField("ON DELETE", text: $draft.onDelete)
        } header: {
            Text("Actions")
        } footer: {
            Text("Leave blank to use database defaults.")
        }
    }
}
