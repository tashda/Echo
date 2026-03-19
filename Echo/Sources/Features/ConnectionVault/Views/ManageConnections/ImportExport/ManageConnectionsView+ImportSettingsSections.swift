import SwiftUI

// MARK: - Import Settings Connections, Identities, and Footer Sections

extension ManageConnectionsView {

    func importConnectionsSection(source: Project) -> some View {
        let conns = connectionStore.connections.filter { $0.projectID == source.id }
        return VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("CONNECTIONS (\(conns.count))")
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button(importSelectedConnectionIDs.count == conns.count ? "Deselect All" : "Select All") {
                    if importSelectedConnectionIDs.count == conns.count {
                        importSelectedConnectionIDs.removeAll()
                    } else {
                        importSelectedConnectionIDs = Set(conns.map(\.id))
                    }
                }
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.accent)
            }
            .font(TypographyTokens.detail.weight(.bold))
            .foregroundStyle(ColorTokens.Text.secondary)

            if conns.isEmpty {
                Text("No connections in this project").font(TypographyTokens.caption2).italic()
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(conns.sorted(by: { $0.connectionName < $1.connectionName })) { conn in
                        Toggle(isOn: Binding(
                            get: { importSelectedConnectionIDs.contains(conn.id) },
                            set: { val in
                                if val { importSelectedConnectionIDs.insert(conn.id) }
                                else { importSelectedConnectionIDs.remove(conn.id) }
                            }
                        )) {
                            Label(conn.connectionName, systemImage: "externaldrive")
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Text.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs))
            }
        }
    }

    func importIdentitiesSection(source: Project) -> some View {
        let ids = connectionStore.identities.filter { $0.projectID == source.id }
        return VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack {
                Text("IDENTITIES (\(ids.count))")
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button(importSelectedIdentityIDs.count == ids.count ? "Deselect All" : "Select All") {
                    if importSelectedIdentityIDs.count == ids.count {
                        importSelectedIdentityIDs.removeAll()
                    } else {
                        importSelectedIdentityIDs = Set(ids.map(\.id))
                    }
                }
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.accent)
            }
            .font(TypographyTokens.detail.weight(.bold))
            .foregroundStyle(ColorTokens.Text.secondary)

            if ids.isEmpty {
                Text("No identities in this project").font(TypographyTokens.caption2).italic()
            } else {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    ForEach(ids.sorted(by: { $0.name < $1.name })) { identity in
                        Toggle(isOn: Binding(
                            get: { importSelectedIdentityIDs.contains(identity.id) },
                            set: { val in
                                if val { importSelectedIdentityIDs.insert(identity.id) }
                                else { importSelectedIdentityIDs.remove(identity.id) }
                            }
                        )) {
                            Label(identity.name, systemImage: "person.crop.circle")
                                .font(TypographyTokens.standard)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Text.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: SpacingTokens.xs))
            }
        }
    }

    func importFooterView(source: Project, targetID: UUID) -> some View {
        HStack {
            Spacer()
            Button("Cancel") {
                showImportSettingsPopup = false
                importSettingsSourceProject = nil
            }
            .keyboardShortcut(.cancelAction)

            Button("Import Selected Items") {
                Task {
                    try? await projectStore.importProjectResources(
                        from: source,
                        into: targetID,
                        connectionStore: connectionStore,
                        merge: importSettingsMerge,
                        includeSettings: importIncludeSettings,
                        connectionIDs: importSelectedConnectionIDs,
                        identityIDs: importSelectedIdentityIDs
                    )
                    showImportSettingsPopup = false
                    importSettingsSourceProject = nil
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(importSelectedConnectionIDs.isEmpty && importSelectedIdentityIDs.isEmpty && !importIncludeSettings)
        }
        .padding(SpacingTokens.md)
    }
}
