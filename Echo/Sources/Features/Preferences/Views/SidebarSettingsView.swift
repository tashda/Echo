import SwiftUI

struct SidebarSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    private var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        Form {
            Section {
                Toggle("Expand one connection at a time", isOn: expandOneConnectionToggle)
            } header: {
                Text("Object Browser")
            } footer: {
                Text("Collapse other connections when opening a server.")
            }

            Section {
                Toggle("Pin server and database while scrolling", isOn: pinnedPathToggle)
                Toggle("Show empty folders", isOn: emptyFoldersToggle)
                Toggle("Show scroll bar", isOn: scrollBarToggle)
            } footer: {
                Text("Pinning shows the server and database you are scrolled into at the top of the Explorer. Empty folders such as Views or Functions with nothing in them are hidden unless shown here. The scroll bar is hidden unless shown here; the rail shows which server you're in.")
            }

            Section {
                Picker("Clicking a server while the Explorer is hidden", selection: projectStore.globalSettingBinding(\.collapsedServerClick)) {
                    ForEach(CollapsedServerClickBehavior.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Server Rail")
            } footer: {
                Text("Peek slides that server's tree out over your work; click anywhere else to close it.")
            }

            Section("Databases") {
                Toggle("Hide offline databases by default", isOn: hideOfflineToggle)
            }

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

    // MARK: - Hide offline toggle

    private var expandOneConnectionToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarExpandOneConnectionAtATime },
            set: { enabled in
                var updated = settings
                updated.sidebarExpandOneConnectionAtATime = enabled
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private var emptyFoldersToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarShowsEmptyFolders },
            set: { enabled in
                var updated = settings
                updated.sidebarShowsEmptyFolders = enabled
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private var scrollBarToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarShowsScrollBar },
            set: { enabled in
                var updated = settings
                updated.sidebarShowsScrollBar = enabled
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private var pinnedPathToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarShowsPinnedPath },
            set: { enabled in
                var updated = settings
                updated.sidebarShowsPinnedPath = enabled
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private var hideOfflineToggle: Binding<Bool> {
        Binding(
            get: { settings.sidebarHideOfflineDatabasesByDefault },
            set: { enabled in
                var updated = settings
                updated.sidebarHideOfflineDatabasesByDefault = enabled
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
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
