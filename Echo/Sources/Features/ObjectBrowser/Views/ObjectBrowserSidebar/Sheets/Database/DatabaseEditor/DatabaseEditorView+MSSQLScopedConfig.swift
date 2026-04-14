import SwiftUI
import SQLServerKit

// MARK: - Scoped Configurations Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlScopedConfigurationsPage() -> some View {
        if viewModel.scopedConfigurations.isEmpty {
            ContentUnavailableView(
                "No Scoped Configurations",
                systemImage: "slider.horizontal.3",
                description: Text("Database scoped configurations are available on SQL Server 2016+.")
            )
        } else {
            ForEach(viewModel.scopedConfigurations) { config in
                scopedConfigRow(config)
            }
        }
    }

    @ViewBuilder
    private func scopedConfigRow(_ config: SQLServerScopedConfiguration) -> some View {
        let info = scopedConfigDescription(config.name)
        let controlType = scopedConfigControlType(config)

        switch controlType {
        case .toggle(let isOn):
            PropertyRow(title: config.name, info: info) {
                Toggle("", isOn: scopedConfigToggleBinding(config, currentlyOn: isOn))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

        case .picker(let options):
            PropertyRow(title: config.name, info: info) {
                Picker("", selection: scopedConfigPickerBinding(config)) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

        case .numeric:
            PropertyRow(title: config.name, info: info) {
                Text(config.value)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

        case .readOnly:
            PropertyRow(title: config.name, info: info) {
                Text(config.value)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
