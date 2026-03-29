import SwiftUI

struct FunctionEditorDefinitionPage: View {
    @Bindable var viewModel: FunctionEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            languageHeader
            codeEditor
        }
    }

    // MARK: - Language Header

    private var languageHeader: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Language: \(viewModel.language)")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    // MARK: - Code Editor

    private var codeEditor: some View {
        TextEditor(text: $viewModel.body)
            .font(TypographyTokens.code)
            .scrollContentBackground(.hidden)
            .padding(SpacingTokens.sm)
    }
}
