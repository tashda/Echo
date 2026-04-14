import SwiftUI

struct SearchSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    private var settings: GlobalSettings {
        projectStore.globalSettings
    }

    var body: some View {
        Form {
            Section("Scope") {
                Toggle("Include offline databases", isOn: includeOfflineBinding)
                Text("Offline and inaccessible databases are excluded from search results and the database scope picker by default.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }

            Section("Query") {
                Picker("Minimum query length", selection: minQueryLengthBinding) {
                    Text("1 character").tag(1)
                    Text("2 characters").tag(2)
                    Text("3 characters").tag(3)
                }
                .pickerStyle(.menu)
            }

            Section("Default Filters") {
                Text("Choose which object types are included by default when opening the Search sidebar.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)

                ForEach(SearchSidebarCategory.allCases) { category in
                    Toggle(category.displayName, isOn: categoryToggle(for: category))
                }

                HStack {
                    Spacer()
                    Button("Select All") { setAllCategories(true) }
                    Button("Reset to Default") { resetCategories() }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Bindings

    private var includeOfflineBinding: Binding<Bool> {
        Binding(
            get: { settings.searchIncludeOfflineDatabases },
            set: { newValue in
                var updated = settings
                updated.searchIncludeOfflineDatabases = newValue
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private var minQueryLengthBinding: Binding<Int> {
        Binding(
            get: { settings.searchMinimumQueryLength },
            set: { newValue in
                var updated = settings
                updated.searchMinimumQueryLength = newValue
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private func categoryToggle(for category: SearchSidebarCategory) -> Binding<Bool> {
        Binding(
            get: {
                let defaults = settings.searchDefaultCategories ?? Set(SearchSidebarCategory.allCases.map(\.rawValue))
                return defaults.contains(category.rawValue)
            },
            set: { newValue in
                var updated = settings
                var current = updated.searchDefaultCategories ?? Set(SearchSidebarCategory.allCases.map(\.rawValue))
                if newValue {
                    current.insert(category.rawValue)
                } else {
                    current.remove(category.rawValue)
                }
                updated.searchDefaultCategories = current
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    private func setAllCategories(_ enabled: Bool) {
        var updated = settings
        if enabled {
            updated.searchDefaultCategories = Set(SearchSidebarCategory.allCases.map(\.rawValue))
        } else {
            updated.searchDefaultCategories = []
        }
        Task { try? await projectStore.updateGlobalSettings(updated) }
    }

    private func resetCategories() {
        var updated = settings
        updated.searchDefaultCategories = nil
        Task { try? await projectStore.updateGlobalSettings(updated) }
    }
}
