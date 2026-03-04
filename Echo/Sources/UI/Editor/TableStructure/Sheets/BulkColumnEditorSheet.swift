import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

enum BulkColumnEditValue {
    case dataType(String)
    case defaultValue(String?)
    case generatedExpression(String?)
}

struct BulkColumnEditorSheet: View {
    let mode: BulkColumnEditorPresentation.Mode
    let columnNames: [String]
    let onApply: (BulkColumnEditValue) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var dataType: String = ""
    @State private var defaultValue: String = ""
    @State private var generatedExpression: String = ""
    @State private var selectedPresetType: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            contentForm

            Divider()

            toolbar
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: formHeight)
        .navigationTitle("Edit Columns")
    }

    private var contentForm: some View {
        Form {
            Section {
                sectionContent
            } header: {
                sectionHeader
            } footer: {
                sectionFooter
            }
            .textCase(nil)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch mode {
        case .dataType: dataTypeFields
        case .defaultValue: defaultValueField
        case .generatedExpression: generatedExpressionField
        }
    }

    private var dataTypeFields: some View {
        Group {
            TableStructureSheetHelpers.labeledRow(title: "Data Type") {
                dataTypePicker
            }

            if needsCustomTypeField {
                TableStructureSheetHelpers.labeledRow(title: "Custom Data Type") {
                    inlineField(text: $dataType, alignment: .trailing)
                }
            }
        }
    }

    private var defaultValueField: some View {
        TableStructureSheetHelpers.labeledRow(title: "Default Value") {
            inlineField(text: $defaultValue, alignment: .trailing)
        }
    }

    private var generatedExpressionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Generated Expression")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $generatedExpression)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
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

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(columnSummaryTitle)
                .font(.system(size: 12, weight: .semibold))
            if columnNames.isEmpty {
                Text("No columns selected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(columnNames.prefix(10).enumerated()), id: \.offset) { _, name in
                    Text("• \(name)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if columnNames.count > 10 {
                    Text("…and \(columnNames.count - 10) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text(sectionTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }

    private var columnSummaryTitle: String {
        let count = columnNames.count
        if count == 0 {
            return "Applying changes"
        } else if count == 1 {
            return "Applying changes to 1 column"
        } else {
            return "Applying changes to \(count) columns"
        }
    }

    private var needsCustomTypeField: Bool {
        mode == .dataType && selectedPresetType == nil
    }

    @ViewBuilder
    private var dataTypePicker: some View {
        Picker("", selection: presetTypeBinding) {
            ForEach(postgresDataTypeOptions, id: \.self) { option in
                Text(option).tag(Optional(option))
            }
            Text("Custom…").tag(Optional<String>.none)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 180, alignment: .trailing)
    }

    private var presetTypeBinding: Binding<String?> {
        Binding(
            get: { selectedPresetType },
            set: { newValue in
                selectedPresetType = newValue
                if let preset = newValue {
                    dataType = preset
                }
            }
        )
    }

    private func inlineField(text: Binding<String>, alignment: TextAlignment) -> some View {
        let frameAlignment: Alignment
        switch alignment {
        case .trailing: frameAlignment = .trailing
        case .center: frameAlignment = .center
        default: frameAlignment = .leading
        }

        return TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var sectionTitle: String {
        switch mode {
        case .dataType: return "Data Type"
        case .defaultValue: return "Default"
        case .generatedExpression: return "Generated Expression"
        }
    }

    @ViewBuilder
    private var sectionFooter: some View {
        switch mode {
        case .dataType:
            EmptyView()
        case .defaultValue, .generatedExpression:
            Text("Leave empty to clear the value on all selected columns.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Apply") {
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
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canApply)
            .tint(themeManager.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(toolbarBackgroundColor)
        .overlay(
            Rectangle()
                .fill(toolbarBorderColor)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var canApply: Bool {
        switch mode {
        case .dataType:
            if let preset = selectedPresetType {
                return !preset.isEmpty
            }
            return !dataType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .defaultValue, .generatedExpression:
            return true
        }
    }

    private var formHeight: CGFloat {
        switch mode {
        case .dataType:
            return 280
        case .defaultValue:
            return 250
        case .generatedExpression:
            return 360
        }
    }

    private var fieldBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor).opacity(0.9)
#else
        themeManager.surfaceBackgroundColor.opacity(0.9)
#endif
    }

    private var fieldStrokeColor: Color {
        let foreground = themeManager.surfaceForegroundColor
        return foreground.opacity(themeManager.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    private var toolbarBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: themeManager.surfaceBackgroundNSColor)
#else
        themeManager.surfaceBackgroundColor
#endif
    }

    private var toolbarBorderColor: Color {
        themeManager.surfaceForegroundColor.opacity(themeManager.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }
}
