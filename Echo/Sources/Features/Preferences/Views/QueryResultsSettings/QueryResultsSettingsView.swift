import SwiftUI

struct QueryResultsSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @EnvironmentObject internal var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            Section("Appearance") {
                SettingsRowWithInfo(
                    title: "Alternate row shading",
                    description: "Applies alternating background colors to result table rows for easier reading."
                ) {
                    Toggle("", isOn: alternateRowShadingBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Section("Foreign Key Cells") {
                SettingsRowWithInfo(
                    title: "Cell Behaviour",
                    description: displayDescription(for: selectedDisplayMode)
                ) {
                    Picker("", selection: displayModeBinding) {
                        ForEach(ForeignKeyDisplayMode.allCases, id: \.self) { mode in
                            Text(displayName(for: mode)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if selectedDisplayMode == .showInspector {
                    SettingsRowWithInfo(
                        title: "Inspector Behaviour",
                        description: behaviorDescription(for: selectedBehavior)
                    ) {
                        Picker("", selection: inspectorBehaviorBinding) {
                            ForEach(ForeignKeyInspectorBehavior.allCases, id: \.self) { behavior in
                                Text(behaviorDisplayName(for: behavior)).tag(behavior)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    SettingsRowWithInfo(
                        title: "Include related foreign keys",
                        description: "When enabled, the inspector also loads rows referenced by the selected record's foreign keys."
                    ) {
                        Toggle("", isOn: includeRelatedBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            Section("Inspector") {
                SettingsRowWithInfo(
                    title: "Auto-open on selection",
                    description: "Automatically opens the inspector panel when selecting items like job history rows."
                ) {
                    Toggle("", isOn: autoOpenInspectorBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
