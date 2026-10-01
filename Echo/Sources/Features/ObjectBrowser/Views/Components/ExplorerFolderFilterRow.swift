import SwiftUI

/// The row at the top of a folder that narrows it as you type (round 42.6). Escape or the close
/// button removes the filter and shows every row again.
struct ExplorerFolderFilterRow: View {
    let filter: ExplorerFolderFilter
    let depth: Int

    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            TextField("", text: $text, prompt: Text(filter.prompt))
                .textFieldStyle(.plain)
                .font(TypographyTokens.standard)
                .focused($isFocused)
                .onSubmit { isFocused = false }
                .onExitCommand { filter.close() }
            Button(action: filter.close) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove the filter")
        }
        .padding(.leading, CGFloat(depth) * SidebarRowConstants.indentStep
                 + SidebarRowConstants.rowOuterHorizontalPadding + SidebarRowConstants.rowLeadingPadding)
        .padding(.trailing, SidebarRowConstants.rowOuterHorizontalPadding)
        .onAppear {
            text = filter.text()
            isFocused = true
        }
        .onChange(of: text) { _, new in filter.setText(new) }
    }
}
