import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Parameters Page

extension DatabaseEditorView {

    @ViewBuilder
    func postgresParametersPage() -> some View {
        if viewModel.pgSettingDefinitions.isEmpty {
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

                ForEach(Array(viewModel.pgParams.enumerated()), id: \.offset) { index, param in
                    pgParameterRow(index: index, param: param)
                }
            } header: {
                HStack {
                    Text("Database Parameters")
                    Spacer()
                    Text("\(viewModel.pgParams.count) configured")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
    }

    // MARK: - Parameter Picker

    @ViewBuilder
    private var pgParameterPicker: some View {
        let available = viewModel.pgAvailableParameters
        let groupedParams = Dictionary(grouping: available, by: \.category)
        let sortedCategories = groupedParams.keys.sorted()

        Picker("Add Parameter", selection: Binding(
            get: { "" },
            set: { name in
                guard !name.isEmpty else { return }
                viewModel.pgAddParameterWithDefault(name: name)
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
    private func pgParameterRow(index: Int, param: PostgresDatabaseParameter) -> some View {
        let def = viewModel.pgSettingDefinition(for: param.name)
        HStack(spacing: SpacingTokens.xs) {
            Text(param.name)
                .font(TypographyTokens.standard)
                .lineLimit(1)

            if let def, !def.shortDesc.isEmpty {
                PgInfoPopoverButton(text: def.shortDesc)
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
                ForEach(viewModel.pgRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Button(role: .destructive) {
                viewModel.pgParams.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Value Editors

    @ViewBuilder
    private func pgParameterValueEditor(index: Int, def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            Toggle("", isOn: Binding<Bool>(
                get: { viewModel.pgParams[safe: index]?.value == "on" },
                set: { newVal in
                    guard viewModel.pgParams[safe: index] != nil else { return }
                    viewModel.pgParams[index] = PostgresDatabaseParameter(name: def.name, value: newVal ? "on" : "off")
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

        case "enum":
            Picker("", selection: Binding<String>(
                get: { viewModel.pgParams[safe: index]?.value ?? "" },
                set: { newVal in
                    guard viewModel.pgParams[safe: index] != nil else { return }
                    viewModel.pgParams[index] = PostgresDatabaseParameter(name: def.name, value: newVal)
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

    // MARK: - Binding Helpers

    private func pgParamTextBinding(index: Int, def: PostgresSettingDefinition) -> Binding<String> {
        Binding(
            get: { viewModel.pgParams[safe: index]?.value ?? "" },
            set: { viewModel.pgParams[safe: index] != nil ? viewModel.pgParams[index] = PostgresDatabaseParameter(name: def.name, value: $0) : () }
        )
    }

    private func pgParamRoleBinding(index: Int, param: PostgresDatabaseParameter) -> Binding<String> {
        Binding(get: { "" }, set: { _ in })
    }
}

// MARK: - Info Popover Button

private struct PgInfoPopoverButton: View {
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
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

extension Array {
    fileprivate subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
