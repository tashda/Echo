import SwiftUI
import PostgresKit

struct PgRoleEditorParametersPage: View {
    @Bindable var viewModel: PgRoleEditorViewModel

    @State private var newParamName = ""
    @State private var newParamValue = ""

    private var availableParameters: [PostgresSettingDefinition] {
        let existing = Set(viewModel.roleParameters.map(\.name))
        return viewModel.settingDefinitions.filter { !existing.contains($0.name) }
    }

    var body: some View {
        currentParametersSection
        addParameterSection
        infoSection
    }

    // MARK: - Current Parameters

    @ViewBuilder
    private var currentParametersSection: some View {
        Section("Role Parameters") {
            if viewModel.roleParameters.isEmpty {
                Text("No role-level parameters configured.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.formDescription)
            }

            ForEach(Array(viewModel.roleParameters.enumerated()), id: \.element.id) { index, param in
                parameterRow(index: index, param: param)
            }
        }
    }

    @ViewBuilder
    private func parameterRow(index: Int, param: PgRoleParameterDraft) -> some View {
        let def = viewModel.settingDefinitions.first(where: { $0.name == param.name })
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

            Text(param.value)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)

            if let def, !def.unit.isEmpty {
                Text(def.unit)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }

            Button(role: .destructive) {
                viewModel.roleParameters.remove(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Parameter

    @ViewBuilder
    private var addParameterSection: some View {
        Section("Add Parameter") {
            let grouped = Dictionary(grouping: availableParameters, by: \.category)
            let sortedCategories = grouped.keys.sorted()

            Picker("Parameter", selection: $newParamName) {
                Text("Select parameter\u{2026}").tag("")
                ForEach(sortedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(grouped[category] ?? [], id: \.name) { def in
                            Text(def.name).tag(def.name)
                        }
                    }
                }
            }

            if !newParamName.isEmpty,
               let def = viewModel.settingDefinitions.first(where: { $0.name == newParamName }) {
                parameterValueInput(def: def)

                if !def.shortDesc.isEmpty {
                    Text(def.shortDesc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func parameterValueInput(def: PostgresSettingDefinition) -> some View {
        switch def.vartype {
        case "bool":
            HStack {
                Picker("Value", selection: $newParamValue) {
                    Text("on").tag("on")
                    Text("off").tag("off")
                }
                .onAppear {
                    if newParamValue.isEmpty { newParamValue = def.bootVal == "on" ? "on" : "off" }
                }
                addButton
            }

        case "enum":
            HStack {
                Picker("Value", selection: $newParamValue) {
                    Text("Select\u{2026}").tag("")
                    ForEach(def.enumVals, id: \.self) { val in
                        Text(val).tag(val)
                    }
                }
                addButton
            }

        default:
            LabeledContent("Value") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", text: $newParamValue, prompt: Text("e.g. value"))
                        .frame(minWidth: 120)
                    if !def.unit.isEmpty {
                        Text(def.unit)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    addButton
                }
            }
        }
    }

    private var addButton: some View {
        Button("Add") {
            let trimmed = newParamValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newParamName.isEmpty, !trimmed.isEmpty else { return }
            viewModel.roleParameters.append(
                PgRoleParameterDraft(name: newParamName, value: trimmed)
            )
            newParamName = ""
            newParamValue = ""
        }
        .disabled(newParamValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Info

    @ViewBuilder
    private var infoSection: some View {
        if !viewModel.settingDefinitions.isEmpty {
            Section {
                Text("\(viewModel.settingDefinitions.count) configurable parameters available.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }
}
