import SwiftUI

/// The ⌘K palette (plan K4): a centred glass card with a field and the matching rows. Arrows move
/// the selection, Return performs it, Esc closes.
struct CommandPaletteCard: View {
    @Bindable var model: CommandPaletteModel
    let onClose: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            field
            if !model.results.isEmpty || !model.query.isEmpty {
                CommandPaletteResultsList(model: model, onPerform: onClose)
            }
        }
        .padding(LayoutTokens.FloatingSurface.padding)
        .frame(width: LayoutTokens.CommandPalette.width)
        // Glass on the card itself, not a GlassEffectContainer: a text field inside a container
        // sent AppKit's autofill into an endless key-view walk (round 10).
        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
        .onAppear { isFieldFocused = true }
        .onExitCommand(perform: onClose)
    }

    private var field: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
            TextField("Search", text: $model.query, prompt: Text("Search objects, tabs, actions and snippets"))
                .textFieldStyle(.plain)
                .font(TypographyTokens.title3)
                .labelsHidden()
                .focused($isFieldFocused)
                .onSubmit {
                    if model.performSelected() { onClose() }
                }
                .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                .onKeyPress(.escape) { onClose(); return .handled }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.CommandPalette.fieldHeight)
    }
}
