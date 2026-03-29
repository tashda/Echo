import SwiftUI

struct QueryResultFormView: View {
    let record: QueryResultDetailRecord
    let rowCount: Int
    let onMoveToRow: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Form {
                Section("Record") {
                    ForEach(record.fields) { field in
                        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                            HStack(spacing: SpacingTokens.xs) {
                                Text(field.name)
                                    .font(TypographyTokens.formValue.weight(.semibold))
                                if field.isPrimaryKey {
                                    badge("Primary Key")
                                }
                                if !field.isNullable {
                                    badge("Required")
                                }
                            }

                            Text(field.value)
                                .font(TypographyTokens.Table.sql)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, SpacingTokens.xs)
                                .padding(.horizontal, SpacingTokens.xs2)
                                .background(
                                    RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                                        .fill(ColorTokens.Background.secondary)
                                )

                            LabeledContent("Type", value: field.dataType)
                            if let comment = field.comment, !comment.isEmpty {
                                LabeledContent("Comment", value: comment)
                            }
                        }
                        .padding(.vertical, SpacingTokens.xxs2)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Row \(record.rowIndex + 1) of \(rowCount)")
                .font(TypographyTokens.formValue)
                .foregroundStyle(ColorTokens.Text.secondary)

            Spacer()

            Button {
                onMoveToRow(record.rowIndex - 1)
            } label: {
                Label("Previous", systemImage: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(record.rowIndex <= 0)

            Button {
                onMoveToRow(record.rowIndex + 1)
            } label: {
                Label("Next", systemImage: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(record.rowIndex >= rowCount - 1)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.caption2.weight(.semibold))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs2)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(
                Capsule(style: .continuous)
                    .fill(ColorTokens.Background.secondary)
            )
    }
}
