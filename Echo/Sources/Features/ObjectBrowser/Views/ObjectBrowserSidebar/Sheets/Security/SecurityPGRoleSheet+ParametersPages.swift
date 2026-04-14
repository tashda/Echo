import SwiftUI
import PostgresKit

// MARK: - SecurityPGRoleSheet Parameters Page

extension SecurityPGRoleSheet {

    // MARK: - Parameters Page

    @ViewBuilder
    var parametersPage: some View {
        if settingDefinitions.isEmpty {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading parameter definitions\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Role Parameters") {
                if roleParameters.isEmpty && !isEditing {
                    Text("No role-level parameters configured.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.detail)
                }

                ForEach(Array(roleParameters.enumerated()), id: \.offset) { index, param in
                    parameterRow(index: index, param: param)
                }
            }

            if isEditing {
                Section("Add Parameter") {
                    parameterAddControls
                }
            }

            Section {
                Text("\(settingDefinitions.count) configurable parameters available from this server.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    @ViewBuilder
    func parameterRow(index: Int, param: PostgresDatabaseParameter) -> some View {
        let def = settingDefinition(for: param.name)
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(param.name)
                    .font(TypographyTokens.standard)
                if let def, !def.shortDesc.isEmpty {
                    Text(def.shortDesc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 200, alignment: .leading)

            Spacer()

            if isEditing, let def {
                parameterValueEditor(index: index, def: def)
            } else {
                Text(param.value)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
                if let def, !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            if isEditing {
                Button(role: .destructive) {
                    roleParameters.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(ColorTokens.Status.error)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func parameterValueEditor(index: Int, def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            let isOn = Binding<Bool>(
                get: { roleParameters[safe: index]?.value == "on" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0 ? "on" : "off") : () }
            )
            Toggle("", isOn: isOn)
                .labelsHidden()

        case "enum":
            let selection = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            Picker("", selection: selection) {
                ForEach(def.enumVals, id: \.self) { val in
                    Text(val).tag(val)
                }
            }
            .labelsHidden()
            .frame(minWidth: 120)

        case "integer", "real":
            let text = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", text: text, prompt: Text("value"))
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                if !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

        default: // string
            let text = Binding<String>(
                get: { roleParameters[safe: index]?.value ?? "" },
                set: { roleParameters[safe: index] != nil ? roleParameters[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            TextField("", text: text, prompt: Text("value"))
                .frame(minWidth: 120)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
