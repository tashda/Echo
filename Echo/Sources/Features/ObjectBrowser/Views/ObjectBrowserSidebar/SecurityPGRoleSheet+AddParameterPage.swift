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
        .frame(minWidth: 200)

        if !newParamName.isEmpty, let def = settingDefinition(for: newParamName) {
            HStack(spacing: SpacingTokens.xs) {
                switch def.vartype {
                case "bool":
                    Picker("Value", selection: $newParamValue) {
                        Text("on").tag("on")
                        Text("off").tag("off")
                    }
                    .frame(width: 100)
                    .onAppear { if newParamValue.isEmpty { newParamValue = def.bootVal == "on" ? "on" : "off" } }

                case "enum":
                    Picker("Value", selection: $newParamValue) {
                        Text("Select\u{2026}").tag("")
                        ForEach(def.enumVals, id: \.self) { val in
                            Text(val).tag(val)
                        }
                    }
                    .frame(minWidth: 120)

                case "integer", "real":
                    TextField("Value", text: $newParamValue)
                        .frame(width: 100)
                    if !def.unit.isEmpty {
                        Text(def.unit)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }

                default:
                    TextField("Value", text: $newParamValue)
                        .frame(minWidth: 120)
                }

                Button("Add") {
                    addParameter()
                }
                .disabled(newParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !def.shortDesc.isEmpty {
                Text(def.shortDesc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
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
                HStack {
                    Text(label.provider)
                        .font(TypographyTokens.standard)
                        .frame(minWidth: 120, alignment: .leading)
                    Text(label.label)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
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

        if isEditing {
            Section("Add Security Label") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("Provider", text: $newLabelProvider)
                        .frame(minWidth: 120)

                    TextField("Label", text: $newLabelValue)

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
