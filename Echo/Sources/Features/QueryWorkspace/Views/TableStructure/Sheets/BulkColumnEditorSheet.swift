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
    let databaseType: DatabaseType
    let onApply: (BulkColumnEditValue) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppearanceStore.self) internal var appearanceStore
    @State internal var dataType: String = ""
    @State internal var defaultValue: String = ""
    @State internal var generatedExpression: String = ""
    @State internal var selectedPresetType: String? = nil

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

    var columnSummaryTitle: String {
        let count = columnNames.count
        if count == 0 {
            return "Applying changes"
        } else if count == 1 {
            return "Applying changes to 1 column"
        } else {
            return "Applying changes to \(count) columns"
        }
    }

    var needsCustomTypeField: Bool {
        mode == .dataType && selectedPresetType == nil
    }

    @ViewBuilder
    var dataTypePicker: some View {
        Picker("", selection: presetTypeBinding) {
            ForEach(dataTypeOptions(for: databaseType), id: \.self) { option in
                Text(option).tag(Optional(option))
            }
            Text("Custom...").tag(Optional<String>.none)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: 180, alignment: .trailing)
    }

    var presetTypeBinding: Binding<String?> {
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

    func inlineField(text: Binding<String>, alignment: TextAlignment) -> some View {
        let frameAlignment: Alignment
        switch alignment {
        case .trailing: frameAlignment = .trailing
        case .center: frameAlignment = .center
        default: frameAlignment = .leading
        }

        return TextField("", text: text)
            .textFieldStyle(.plain)
            .font(TypographyTokens.standard)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    var sectionTitle: String {
        switch mode {
        case .dataType: return "Data Type"
        case .defaultValue: return "Default"
        case .generatedExpression: return "Generated Expression"
        }
    }

    var canApply: Bool {
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

    var formHeight: CGFloat {
        switch mode {
        case .dataType:
            return 280
        case .defaultValue:
            return 250
        case .generatedExpression:
            return 360
        }
    }

    var fieldBackgroundColor: Color {
        ColorTokens.Background.secondary.opacity(0.9)
    }

    var fieldStrokeColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.18 : 0.25)
    }

    var toolbarBackgroundColor: Color {
        ColorTokens.Background.secondary
    }

    var toolbarBorderColor: Color {
        ColorTokens.Text.primary.opacity(appearanceStore.effectiveColorScheme == .dark ? 0.3 : 0.12)
    }
}
