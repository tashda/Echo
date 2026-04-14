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
                    .buttonStyle(.bordered)

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
            RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small)
                .fill(ColorTokens.Status.warning.opacity(0.15))
                .stroke(ColorTokens.Status.warning.opacity(0.4), lineWidth: 1)
        }
        .contextMenu {
            Button {
                editText = annotation.text
                isEditing = true
            } label: {
                Label("Edit Note", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Note", systemImage: "trash")
            }
        }
        .onTapGesture(count: 2) {
            editText = annotation.text
            isEditing = true
        }
    }
}
