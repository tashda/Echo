import SwiftUI

struct SidebarSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    private var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        Form {
            Section("General") {
                ForEach(SidebarAutoExpandSection.generalSections) { section in
                    Toggle(section.displayName, isOn: generalToggle(for: section))
                }
            }

            Section {
                Toggle("Customize per database type", isOn: customizeToggle)
            } footer: {
                Text("Override the general settings for specific database types. Each type starts with the general selections plus its unique sections.")
            }

            if settings.sidebarCustomizePerDatabaseType {
                databaseTypeSection(
                    title: "PostgreSQL",
                    databaseType: .postgresql,
                    keyPath: \.sidebarAutoExpandPostgresql
                )
                databaseTypeSection(
                    title: "SQL Server",
                    databaseType: .microsoftSQL,
                    keyPath: \.sidebarAutoExpandSQLServer
                )
                databaseTypeSection(
                    title: "MySQL",
                    databaseType: .mysql,
                    keyPath: \.sidebarAutoExpandMySQL
                )
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - General toggles

    private func generalToggle(for section: SidebarAutoExpandSection) -> Binding<Bool> {
        Binding(
            get: { settings.sidebarAutoExpandSections.contains(section) },
            set: { enabled in
                var updated = settings
                if enabled {
                    updated.sidebarAutoExpandSections.insert(section)
                } else {
                    updated.sidebarAutoExpandSections.remove(section)
                }
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    // MARK: - Customize toggle

    private var customizeToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarCustomizePerDatabaseType },
            set: { enabled in
                var updated = settings
                updated.sidebarCustomizePerDatabaseType = enabled
                if enabled {
                    // Always re-seed per-type overrides from current general settings
                    updated.sidebarAutoExpandPostgresql = seedOverride(for: .postgresql)
                    updated.sidebarAutoExpandSQLServer = seedOverride(for: .microsoftSQL)
                    updated.sidebarAutoExpandMySQL = seedOverride(for: .mysql)
                }
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    /// Seeds a per-type override from the current general settings, filtered to relevant sections.
    private func seedOverride(for databaseType: DatabaseType) -> Set<SidebarAutoExpandSection> {
        let relevant = Set(SidebarAutoExpandSection.allSections(for: databaseType))
        return settings.sidebarAutoExpandSections.intersection(relevant)
    }

    // MARK: - Per-type sections

    @ViewBuilder
    private func databaseTypeSection(
        title: String,
        databaseType: DatabaseType,
        keyPath: WritableKeyPath<GlobalSettings, Set<SidebarAutoExpandSection>?>
    ) -> some View {
        let allSections = SidebarAutoExpandSection.allSections(for: databaseType)
        Section(title) {
            ForEach(allSections) { section in
                Toggle(section.displayName, isOn: overrideToggle(keyPath: keyPath, section: section))
            }
        }
    }

    private func overrideToggle(
        keyPath: WritableKeyPath<GlobalSettings, Set<SidebarAutoExpandSection>?>,
        section: SidebarAutoExpandSection
    ) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath]?.contains(section) ?? false },
            set: { enabled in
                var updated = settings
                var set = updated[keyPath: keyPath] ?? []
                if enabled {
                    set.insert(section)
                } else {
                    set.remove(section)
                }
                updated[keyPath: keyPath] = set
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }
}
