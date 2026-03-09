import SwiftUI

extension BulkColumnEditorSheet {
    var dataTypeFields: some View {
        Group {
            TableStructureSheetComponents.labeledRow(title: "Data Type") {
                dataTypePicker
            }

            if needsCustomTypeField {
                TableStructureSheetComponents.labeledRow(title: "Custom Data Type") {
                    inlineField(text: $dataType, alignment: .trailing)
                }
            }
        }
    }

    var defaultValueField: some View {
        TableStructureSheetComponents.labeledRow(title: "Default Value") {
            inlineField(text: $defaultValue, alignment: .trailing)
        }
    }

    var generatedExpressionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generated Expression")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $generatedExpression)
                .font(TypographyTokens.standard)
                .frame(minHeight: 120)
                .padding(.vertical, SpacingTokens.xxs2)
                .padding(.horizontal, SpacingTokens.xs)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(fieldBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(fieldStrokeColor, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(columnSummaryTitle)
                .font(TypographyTokens.caption2.weight(.semibold))
            if columnNames.isEmpty {
                Text("No columns selected")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(columnNames.prefix(10).enumerated()), id: \.offset) { _, name in
                    Text("-- \(name)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
                if columnNames.count > 10 {
                    Text("...and \(columnNames.count - 10) more")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                }
            }

            Text(sectionTitle)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, SpacingTokens.xxs2)
        }
    }

    @ViewBuilder
    var sectionFooter: some View {
        switch mode {
        case .dataType:
            EmptyView()
        case .defaultValue, .generatedExpression:
            Text("Leave empty to clear the value on all selected columns.")
        }
    }

    var toolbar: some View {
        HStack(spacing: 12) {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Apply") {
                applyChanges()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canApply)
            .tint(appearanceStore.accentColor)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    func applyChanges() {
        switch mode {
        case .dataType:
            let resolved: String
            if let preset = selectedPresetType {
                resolved = preset
            } else {
                let trimmed = dataType.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { onCancel(); return }
                resolved = trimmed
            }
            onApply(.dataType(resolved))
        case .defaultValue:
            let trimmed = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
            onApply(.defaultValue(trimmed.isEmpty ? nil : trimmed))
        case .generatedExpression:
            let trimmed = generatedExpression.trimmingCharacters(in: .whitespacesAndNewlines)
            onApply(.generatedExpression(trimmed.isEmpty ? nil : trimmed))
        }
    }
}
