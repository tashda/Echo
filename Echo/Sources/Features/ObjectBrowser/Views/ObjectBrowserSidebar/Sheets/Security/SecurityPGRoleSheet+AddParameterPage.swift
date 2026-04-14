import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet Add Parameter Controls

extension SecurityPGRoleSheet {

    @ViewBuilder
    var parameterAddControls: some View {
        let groupedParams = Dictionary(grouping: availableParameters, by: \.category)
        let sortedCategories = groupedParams.keys.sorted()

        Picker("Parameter", selection: $newParamName) {
            Text("Select parameter\u{2026}").tag("")
            ForEach(sortedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(groupedParams[category] ?? [], id: \.name) { def in
                        Text(def.name).tag(def.name)
                    }
                }
            }
        }

        if !newParamName.isEmpty, let def = settingDefinition(for: newParamName) {
            parameterAddValueRow(def: def)

            if !def.shortDesc.isEmpty {
                Text(def.shortDesc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    private func parameterAddValueRow(def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            Picker("Value", selection: $newParamValue) {
                Text("on").tag("on")
                Text("off").tag("off")
            }
            .onAppear { if newParamValue.isEmpty { newParamValue = def.bootVal == "on" ? "on" : "off" } }

        case "enum":
            Picker("Value", selection: $newParamValue) {
                Text("Select\u{2026}").tag("")
                ForEach(def.enumVals, id: \.self) { val in
                    Text(val).tag(val)
                }
            }

        case "integer", "real":
            LabeledContent("Value") {
                HStack(spacing: SpacingTokens.xxs) {
                    TextField("", text: $newParamValue)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    if !def.unit.isEmpty {
                        Text(def.unit)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    addParameterButton
                }
            }

        default:
            LabeledContent("Value") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", text: $newParamValue)
                        .frame(minWidth: 120)
                    addParameterButton
                }
            }
        }

        if def.vartype == "bool" || def.vartype == "enum" {
            LabeledContent {
                addParameterButton
            } label: {
                EmptyView()
            }
        }
    }

    private var addParameterButton: some View {
        Button("Add") {
            addParameter()
        }
        .disabled(newParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Security Labels Page

    @ViewBuilder
    var securityLabelsPage: some View {
        Section("Security Labels") {
            if securityLabels.isEmpty && !isEditing {
                Text("No security labels assigned to this role.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            }

            ForEach(Array(securityLabels.enumerated()), id: \.offset) { index, label in
                LabeledContent(label.provider) {
                    HStack(spacing: SpacingTokens.xs) {
                        Text(label.label)
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.secondary)
                        if isEditing {
                            Button(role: .destructive) {
                                securityLabels.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(ColorTokens.Status.error)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }

        if isEditing {
            Section("Add Security Label") {
                LabeledContent("Provider") {
                    TextField("", text: $newLabelProvider, prompt: Text("e.g. selinux"))
                        .frame(minWidth: 120)
                }

                LabeledContent("Label") {
                    TextField("", text: $newLabelValue, prompt: Text("e.g. unconfined_u:object_r:user_t:s0"))
                        .frame(minWidth: 120)
                }

                HStack {
                    Spacer()
                    Button("Add") {
                        addSecurityLabel()
                    }
                    .disabled(newLabelProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newLabelValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - SQL Page

    @ViewBuilder
    var sqlPage: some View {
        Section("Generated SQL") {
            let sql = generateSQL()
            Text(sql)
                .font(TypographyTokens.monospaced)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
