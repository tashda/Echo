import SwiftUI

struct CommandEditorView: View {
    let context: CommandEditorContext
    let onSaveToStep: (String, String) -> Void
    let onUseCommand: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String

    init(context: CommandEditorContext, onSaveToStep: @escaping (String, String) -> Void, onUseCommand: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.context = context
        self.onSaveToStep = onSaveToStep
        self.onUseCommand = onUseCommand
        self.onCancel = onCancel
        self._text = State(initialValue: context.initialText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.stepName != nil ? "Edit Command \u{2014} \(context.stepName!)" : "Edit Command")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                if let stepName = context.stepName {
                    Button("Save to Step") {
                        onSaveToStep(stepName, text)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Use Command") {
                        onUseCommand(text)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)

            Divider()

            TextEditor(text: $text)
                .font(TypographyTokens.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(SpacingTokens.sm)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
