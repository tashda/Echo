import SwiftUI
import Foundation

enum UITestConfiguration {
    static let modeKey = "UITEST_BOOT_MODE"

    static var isRunningQueryEditorDemo: Bool {
        ProcessInfo.processInfo.environment[modeKey] == "QueryEditor"
    }
}

struct QueryEditorUITestHost: View {
    @State private var text = "SELECT \"identifier\" FROM table_name;"
    private let theme = SQLEditorTheme.fallback()
    private let display = SQLEditorDisplayOptions()

    var body: some View {
        SQLEditorView(
            text: $text,
            theme: theme,
            display: display,
            onTextChange: { _ in },
            onSelectionChange: { _ in },
            onSelectionPreviewChange: { _ in }
        )
        .frame(minWidth: 720, minHeight: 360)
        .accessibilityIdentifier("QueryEditorUITestHost")
    }
}
