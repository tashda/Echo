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
            PropertyRow(
                title: "Diagram prefetch",
                info: "Echo can warm diagram data in the background for faster opens. Prefetching is optional so large databases do not fetch unused metadata."
            ) {
                Picker("", selection: prefetchBinding) {
                    ForEach(DiagramPrefetchMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            PropertyRow(
                title: "Background refresh",
                info: "Controls how often Echo re-fetches diagram data in the background to keep it up to date."
            ) {
                Picker("", selection: refreshCadenceBinding) {
                    ForEach(DiagramRefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    private var refreshSection: some View {
        Section("Rendering") {
            PropertyRow(
                title: "Verify diagram data before refresh",
                info: "When enabled, Echo checks that cached diagram data is still valid before using it. Disable for faster opens if data rarely changes."
            ) {
                Toggle("", isOn: verifyBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            PropertyRow(
                title: "Render relationships in large diagrams",
                info: "Disable relationship rendering if diagrams with thousands of edges feel heavy; you can still re-enable it on demand."
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
