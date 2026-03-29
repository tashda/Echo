import SwiftUI

struct ViewEditorDefinitionPage: View {
    @Bindable var viewModel: ViewEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Query Definition")
                    .font(TypographyTokens.formLabel)
                    .foregroundStyle(ColorTokens.Text.primary)
                Spacer()
                if viewModel.isMaterialized && viewModel.isEditing {
                    Text("Materialized views must be dropped and recreated to change the definition.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.top, SpacingTokens.sm)
            .padding(.bottom, SpacingTokens.xs)

            TextEditor(text: $viewModel.definition)
                .font(TypographyTokens.code)
                .scrollContentBackground(.hidden)
                .padding(SpacingTokens.xs)
        }
    }
}
