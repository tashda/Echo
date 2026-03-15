import SwiftUI
import PostgresKit

// MARK: - Enhanced PostgreSQL Parameters Page

extension DatabasePropertiesSheet {

    @ViewBuilder
    func postgresParametersPage() -> some View {
        if pgSettingDefinitions.isEmpty {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading parameter definitions\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Database Parameters") {
                if pgParams.isEmpty {
                    Text("No database-level parameters configured.")
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .font(TypographyTokens.detail)
                }

                ForEach(Array(pgParams.enumerated()), id: \.offset) { index, param in
                    pgParameterRow(index: index, param: param)
                }
            }

            Section("Add Parameter") {
                pgParameterAddControls
            }

            Section {
                Text("\(pgSettingDefinitions.count) configurable parameters available from this server.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    @ViewBuilder
    func pgParameterRow(index: Int, param: PostgresDatabaseParameter) -> some View {
        let def = pgSettingDefinition(for: param.name)
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

            if let def {
                pgParameterValueEditor(index: index, def: def)
            } else {
                Text(param.value)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Button(role: .destructive) {
                let paramName = param.name
                pgParams.remove(at: index)
                applyPgAlter { client in
                    try await client.admin.alterDatabaseReset(name: databaseName, parameter: paramName)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func pgParameterValueEditor(index: Int, def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            let isOn = Binding<Bool>(
                get: { pgParams[safe: index]?.value == "on" },
                set: { newVal in
                    guard pgParams[safe: index] != nil else { return }
                    let value = newVal ? "on" : "off"
                    pgParams[index] = PostgresDatabaseParameter(name: def.name, value: value)
                    applyPgAlter { client in
                        try await client.admin.alterDatabaseSet(name: databaseName, parameter: def.name, value: value)
                    }
                }
            )
            Toggle("", isOn: isOn)
                .labelsHidden()

        case "enum":
            let selection = Binding<String>(
                get: { pgParams[safe: index]?.value ?? "" },
                set: { newVal in
                    guard pgParams[safe: index] != nil else { return }
                    pgParams[index] = PostgresDatabaseParameter(name: def.name, value: newVal)
                    applyPgAlter { client in
                        try await client.admin.alterDatabaseSet(name: databaseName, parameter: def.name, value: newVal)
                    }
                }
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
                get: { pgParams[safe: index]?.value ?? "" },
                set: { pgParams[safe: index] != nil ? pgParams[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", text: text)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .onSubmit {
                        applyPgAlter { client in
                            try await client.admin.alterDatabaseSet(name: databaseName, parameter: def.name, value: text.wrappedValue)
                        }
                    }
                if !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

        default:
            let text = Binding<String>(
                get: { pgParams[safe: index]?.value ?? "" },
                set: { pgParams[safe: index] != nil ? pgParams[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
            )
            TextField("", text: text)
                .frame(minWidth: 120)
                .onSubmit {
                    applyPgAlter { client in
                        try await client.admin.alterDatabaseSet(name: databaseName, parameter: def.name, value: text.wrappedValue)
                    }
                }
        }
    }

    @ViewBuilder
    var pgParameterAddControls: some View {
        let groupedParams = Dictionary(grouping: pgAvailableParameters, by: \.category)
        let sortedCategories = groupedParams.keys.sorted()

        Picker("Parameter", selection: $pgNewParamName) {
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

        if !pgNewParamName.isEmpty, let def = pgSettingDefinition(for: pgNewParamName) {
            HStack(spacing: SpacingTokens.xs) {
                pgNewParameterValueControl(def: def)

                Button("Add") {
                    pgAddParameter()
                }
                .disabled(pgNewParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !def.shortDesc.isEmpty {
                Text(def.shortDesc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    func pgNewParameterValueControl(def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            Picker("Value", selection: $pgNewParamValue) {
                Text("on").tag("on")
                Text("off").tag("off")
            }
            .frame(width: 100)
            .onAppear { if pgNewParamValue.isEmpty { pgNewParamValue = def.bootVal == "on" ? "on" : "off" } }

        case "enum":
            Picker("Value", selection: $pgNewParamValue) {
                Text("Select\u{2026}").tag("")
                ForEach(def.enumVals, id: \.self) { val in
                    Text(val).tag(val)
                }
            }
            .frame(minWidth: 120)

        case "integer", "real":
            TextField("Value", text: $pgNewParamValue)
                .frame(width: 100)
            if !def.unit.isEmpty {
                Text(def.unit)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }

        default:
            TextField("Value", text: $pgNewParamValue)
                .frame(minWidth: 120)
        }
    }

    // MARK: - Parameter Helpers

    var pgAvailableParameters: [PostgresSettingDefinition] {
        let existing = Set(pgParams.map(\.name))
        return pgSettingDefinitions.filter { !existing.contains($0.name) }
    }

    func pgSettingDefinition(for name: String) -> PostgresSettingDefinition? {
        pgSettingDefinitions.first(where: { $0.name == name })
    }

    func pgAddParameter() {
        let value = pgNewParamValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = pgNewParamName
        guard !name.isEmpty, !value.isEmpty else { return }
        pgParams.append(PostgresDatabaseParameter(name: name, value: value))
        pgNewParamName = ""
        pgNewParamValue = ""
        applyPgAlter { client in
            try await client.admin.alterDatabaseSet(name: databaseName, parameter: name, value: value)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
