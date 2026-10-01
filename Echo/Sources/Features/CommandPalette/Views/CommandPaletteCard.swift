import SwiftUI

/// The ⌘K palette (plan K4): a centred glass card with a field and the matching rows. Arrows move
/// the selection, Return performs it, Esc closes.
struct CommandPaletteCard: View {
    @Bindable var model: CommandPaletteModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            field
            if !model.results.isEmpty || !model.query.isEmpty {
                CommandPaletteResultsList(model: model, onPerform: onClose)
            }
            hints
        }
        .padding(LayoutTokens.FloatingSurface.padding)
        .frame(width: LayoutTokens.CommandPalette.width)
        // Glass on the card itself, not a GlassEffectContainer: a text field inside a container
        // sent AppKit's autofill into an endless key-view walk (round 10).
        .glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius, style: .continuous))
    }

    private var field: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
            CommandPaletteSearchField(
                text: $model.query,
                placeholder: "Search objects, tabs, actions and snippets",
                onMove: { model.moveSelection(by: $0) },
                onSubmit: { if model.performSelected() { onClose() } },
                onCancel: onClose
            )
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.CommandPalette.fieldHeight)
    }

    /// What the keys do, so the palette teaches itself.
    private var hints: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("↑↓ Move")
            Text("↩ Open")
            Text("⎋ Close")
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.tertiary)
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.top, SpacingTokens.xxs)
        .accessibilityHidden(true)
    }
}
