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
            Section {
                pgParameterPicker

                ForEach(Array(pgParams.enumerated()), id: \.offset) { index, param in
                    pgParameterRow(index: index, param: param)
                }
            } header: {
                HStack {
                    Text("Database Parameters")
                    Spacer()
                    Text("\(pgParams.count) configured")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
    }

    // MARK: - Parameter Picker

    @ViewBuilder
    var pgParameterPicker: some View {
        let groupedParams = Dictionary(grouping: pgAvailableParameters, by: \.category)
        let sortedCategories = groupedParams.keys.sorted()

        Picker("Add Parameter", selection: Binding(
            get: { "" },
            set: { name in
                guard !name.isEmpty else { return }
                pgAddParameterWithDefault(name: name)
            }
        )) {
            Text("Select parameter\u{2026}").tag("")
            ForEach(sortedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(groupedParams[category] ?? [], id: \.name) { def in
                        Text(def.name).tag(def.name)
                    }
                }
            }
        }
    }

    // MARK: - Parameter Row

    @ViewBuilder
    func pgParameterRow(index: Int, param: PostgresDatabaseParameter) -> some View {
        let def = pgSettingDefinition(for: param.name)
        HStack(spacing: SpacingTokens.xs) {
            Text(param.name)
                .font(TypographyTokens.standard)
                .lineLimit(1)

            if let def, !def.shortDesc.isEmpty {
                pgInfoPopover(text: def.shortDesc)
            }

            Spacer()

            if let def {
                pgParameterValueEditor(index: index, def: def)
            } else {
                Text(param.value)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Picker("", selection: pgParamRoleBinding(index: index, param: param)) {
                Text("All roles").tag("")
                ForEach(pgRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Button(role: .destructive) {
                pgParams.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func pgInfoPopover(text: String) -> some View {
        PgSettingInfoButton(text: text)
    }

    // MARK: - Value Editors

    @ViewBuilder
    func pgParameterValueEditor(index: Int, def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            Toggle("", isOn: Binding<Bool>(
                get: { pgParams[safe: index]?.value == "on" },
                set: { newVal in
                    guard pgParams[safe: index] != nil else { return }
                    pgParams[index] = PostgresDatabaseParameter(name: def.name, value: newVal ? "on" : "off")
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

        case "enum":
            Picker("", selection: Binding<String>(
                get: { pgParams[safe: index]?.value ?? "" },
                set: { newVal in
                    guard pgParams[safe: index] != nil else { return }
                    pgParams[index] = PostgresDatabaseParameter(name: def.name, value: newVal)
                }
            )) {
                ForEach(def.enumVals, id: \.self) { val in
                    Text(val).tag(val)
                }
            }
            .labelsHidden()
            .frame(width: 130)

        case "integer", "real":
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", text: pgParamTextBinding(index: index, def: def), prompt: Text("value"))
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                if !def.unit.isEmpty {
                    Text(def.unit)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

        default:
            TextField("", text: pgParamTextBinding(index: index, def: def), prompt: Text("value"))
                .frame(width: 140)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Helpers

    var pgAvailableParameters: [PostgresSettingDefinition] {
        let existing = Set(pgParams.map(\.name))
        return pgSettingDefinitions.filter { !existing.contains($0.name) }
    }

    func pgSettingDefinition(for name: String) -> PostgresSettingDefinition? {
        pgSettingDefinitions.first(where: { $0.name == name })
    }

    func pgAddParameterWithDefault(name: String) {
        guard let def = pgSettingDefinition(for: name) else { return }
        let defaultValue: String
        switch def.vartype {
        case "bool": defaultValue = def.bootVal.isEmpty ? "off" : def.bootVal
        case "enum": defaultValue = def.enumVals.first ?? def.bootVal
        default: defaultValue = def.bootVal
        }
        pgParams.append(PostgresDatabaseParameter(name: name, value: defaultValue))
    }

    func pgParamTextBinding(index: Int, def: PostgresSettingDefinition) -> Binding<String> {
        Binding(
            get: { pgParams[safe: index]?.value ?? "" },
            set: { pgParams[safe: index] != nil ? pgParams[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
        )
    }

    func pgParamRoleBinding(index: Int, param: PostgresDatabaseParameter) -> Binding<String> {
        Binding(get: { "" }, set: { _ in })
    }

    // MARK: - Save (called on Done)

    func pgSaveParameterChanges() {
        let originalNames = Set(pgOriginalParams.map(\.name))
        let currentNames = Set(pgParams.map(\.name))
        let originalMap = Dictionary(pgOriginalParams.map { ($0.name, $0.value) }, uniquingKeysWith: { _, b in b })

        // Parameters to remove (were in original, no longer present)
        let removed = originalNames.subtracting(currentNames)
        // Parameters to add or update
        var upserted: [(name: String, value: String)] = []
        for param in pgParams {
            if let oldValue = originalMap[param.name] {
                if oldValue != param.value { upserted.append((param.name, param.value)) }
            } else {
                upserted.append((param.name, param.value))
            }
        }

        guard !removed.isEmpty || !upserted.isEmpty else { return }

        let removedList = Array(removed)
        let upsertedList = upserted
        let changeCount = removedList.count + upsertedList.count

        guard let pgSession = session.session as? PostgresSession else { return }
        let client = pgSession.client
        isSaving = true

        Task {
            do {
                for name in removedList {
                    try await client.admin.alterDatabaseReset(name: databaseName, parameter: name)
                }
                for param in upsertedList {
                    try await client.admin.alterDatabaseSet(name: databaseName, parameter: param.name, value: param.value)
                }
                isSaving = false
                environmentState.notificationEngine?.post(
                    category: .databasePropertiesSaved,
                    message: "\(changeCount) parameter\(changeCount == 1 ? "" : "s") updated on \(databaseName)."
                )
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            } catch {
                isSaving = false
                environmentState.notificationEngine?.post(
                    category: .databasePropertiesError,
                    message: error.localizedDescription
                )
            }
        }

        pgOriginalParams = pgParams
    }
}

private struct PgSettingInfoButton: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button { isShowing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(TypographyTokens.standard)
                .padding(SpacingTokens.sm)
                .frame(maxWidth: 280)
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
