import SwiftUI

/// A column row whose name is being edited in place (round 42.2). Return hands the new name on,
/// Escape or leaving the field puts the old one back.
struct ExplorerColumnRenameRow: View {
    let name: String
    let depth: Int
    let commit: (String) -> Void
    let cancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField("", text: $text, prompt: Text(name))
            .textFieldStyle(.roundedBorder)
            .font(TypographyTokens.standard)
            .focused($isFocused)
            .onSubmit { commit(text) }
            .onExitCommand(perform: cancel)
            .onChange(of: isFocused) { _, focused in
                if !focused { cancel() }
            }
            .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep
                     + SidebarRowConstants.rowOuterHorizontalPadding + SidebarRowConstants.rowLeadingPadding)
            .padding(.trailing, SidebarRowConstants.rowOuterHorizontalPadding)
            .onAppear {
                text = name
                isFocused = true
            }
    }
}
