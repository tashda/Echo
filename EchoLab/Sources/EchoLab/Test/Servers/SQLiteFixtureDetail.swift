import AppKit
import EchoDesignSystem
import ServerLabCatalog
import SwiftUI

/// A SQLite fixture: what it holds, and a fresh copy to open in Echo.
struct SQLiteFixtureDetail: View {
    let model: LabServersModel
    let fixture: LabSQLiteFixture

    var body: some View {
        Form {
            Section(fixture.rawValue) {
                Text(fixture.summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                LabeledContent("Made with", value: "sqlite-nio, on this Mac")
            }
            Section {
                Button("Make a fresh copy") { Task { await model.makeSQLiteCopy(fixture) } }
                    .buttonStyle(.borderedProminent)
                if let copy = model.sqliteCopies[fixture] {
                    Text(copy.path).font(TypographyTokens.detail).textSelection(.enabled)
                    HStack {
                        Button("Copy path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(copy.path, forType: .string)
                        }
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([copy]) }
                    }
                }
            } footer: {
                Text("Each copy is the test's own: open it in Echo and change anything.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
