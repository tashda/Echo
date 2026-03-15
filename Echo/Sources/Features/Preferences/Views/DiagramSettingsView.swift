import SwiftUI
import Foundation

struct DiagramSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore

    var body: some View {
        Form {
            prefetchSection
            refreshSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var prefetchSection: some View {
        Section("Prefetching") {
            SettingsRowWithInfo(
                title: "Diagram prefetch",
                description: "Echo can warm diagram data in the background for faster opens. Prefetching is optional so large databases do not fetch unused metadata."
            ) {
                Picker("", selection: prefetchBinding) {
                    ForEach(DiagramPrefetchMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            SettingsRowWithInfo(
                title: "Background refresh",
                description: "Controls how often Echo re-fetches diagram data in the background to keep it up to date."
            ) {
                Picker("", selection: refreshCadenceBinding) {
                    ForEach(DiagramRefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 120, idealWidth: 160, maxWidth: 200, alignment: .trailing)
            }
        }
    }

    private var refreshSection: some View {
        Section("Rendering") {
            SettingsRowWithInfo(
                title: "Verify diagram data before refresh",
                description: "When enabled, Echo checks that cached diagram data is still valid before using it. Disable for faster opens if data rarely changes."
            ) {
                Toggle("", isOn: verifyBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            SettingsRowWithInfo(
                title: "Render relationships in large diagrams",
                description: "Disable relationship rendering if diagrams with thousands of edges feel heavy; you can still re-enable it on demand."
            ) {
                Toggle("", isOn: renderRelationshipsBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var prefetchBinding: Binding<DiagramPrefetchMode> {
        Binding(
            get: { projectStore.globalSettings.diagramPrefetchMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramPrefetchMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var refreshCadenceBinding: Binding<DiagramRefreshCadence> {
        Binding(
            get: { projectStore.globalSettings.diagramRefreshCadence },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramRefreshCadence = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var verifyBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.diagramVerifyBeforeRefresh },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramVerifyBeforeRefresh = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    private var renderRelationshipsBinding: Binding<Bool> {
        Binding(
            get: { projectStore.globalSettings.diagramRenderRelationshipsForLargeDiagrams },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.diagramRenderRelationshipsForLargeDiagrams = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }
}
