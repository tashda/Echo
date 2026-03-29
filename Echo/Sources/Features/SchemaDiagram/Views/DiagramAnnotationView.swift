import SwiftUI

struct DiagramAnnotationView: View {
    let annotation: SchemaDiagramAnnotation
    let zoom: CGFloat
    let onUpdate: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            if isEditing {
                TextEditor(text: $editText)
                    .font(TypographyTokens.caption)
                    .frame(minWidth: 140, maxWidth: 220, minHeight: 40, maxHeight: 120)
                    .scrollContentBackground(.hidden)

                HStack(spacing: SpacingTokens.xs) {
                    Button("Done") {
                        onUpdate(editText)
                        isEditing = false
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        isEditing = false
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            } else {
                Text(annotation.text)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .frame(minWidth: 80, maxWidth: 220, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SpacingTokens.xs)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.yellow.opacity(0.15))
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        }
        .contextMenu {
            Button("Edit Note") {
                editText = annotation.text
                isEditing = true
            }
            Divider()
            Button("Delete Note", role: .destructive) {
                onDelete()
            }
        }
        .onTapGesture(count: 2) {
            editText = annotation.text
            isEditing = true
        }
    }
}
