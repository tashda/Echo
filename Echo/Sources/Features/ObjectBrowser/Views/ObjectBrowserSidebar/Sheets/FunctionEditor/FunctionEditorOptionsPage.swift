import SwiftUI

struct FunctionEditorOptionsPage: View {
    @Bindable var viewModel: FunctionEditorViewModel

    private var returnsSet: Bool {
        let lower = viewModel.returnType.lowercased()
        return lower.hasPrefix("setof") || lower.contains("table")
    }

    var body: some View {
        Section("Language") {
            PropertyRow(title: "Language") {
                Picker("", selection: $viewModel.language) {
                    Text("plpgsql").tag("plpgsql")
                    Text("sql").tag("sql")
                    Text("plpython3u").tag("plpython3u")
                    Text("plperl").tag("plperl")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("Behavior") {
            PropertyRow(
                title: "Volatility",
                info: "VOLATILE: can modify database state. STABLE: no side effects within a scan. IMMUTABLE: always returns same result for same arguments."
            ) {
                Picker("", selection: $viewModel.volatility) {
                    ForEach(FunctionVolatility.allCases) { vol in
                        Text(vol.rawValue).tag(vol)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(
                title: "Parallel Safety",
                info: "Controls whether the function can run in parallel query execution."
            ) {
                Picker("", selection: $viewModel.parallelSafety) {
                    ForEach(FunctionParallelSafety.allCases) { safety in
                        Text(safety.rawValue).tag(safety)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(
                title: "Strict (RETURNS NULL ON NULL INPUT)",
                info: "When enabled, the function returns NULL immediately if any argument is NULL, without executing the body."
            ) {
                Toggle("", isOn: $viewModel.isStrict)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Cost") {
            PropertyRow(
                title: "Execution Cost",
                info: "Estimated cost per function call, in units of cpu_operator_cost. Used by the query planner."
            ) {
                TextField("", text: $viewModel.cost, prompt: Text("100"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            if returnsSet {
                PropertyRow(
                    title: "Estimated Rows",
                    info: "Estimated number of rows returned per call. Used by the planner for set-returning functions."
                ) {
                    TextField("", text: $viewModel.estimatedRows, prompt: Text("1000"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }

        Section("Security") {
            PropertyRow(
                title: "Security Type",
                info: "INVOKER: executes with the privileges of the caller. DEFINER: executes with the privileges of the function owner."
            ) {
                Picker("", selection: $viewModel.securityType) {
                    ForEach(FunctionSecurityType.allCases) { sec in
                        Text(sec.rawValue).tag(sec)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}
