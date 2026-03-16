import SwiftUI

extension ObjectBrowserSidebarView {

    /// Always-visible footer with search field; schema picker shown only when a database is selected.
    var globalFooterView: some View {
        let controlBackground = ColorTokens.Text.primary.opacity(0.04)
        let borderColor = Color.clear

        return VStack(spacing: 0) {
            HStack(spacing: SpacingTokens.xxs2) {
                ExplorerFooterSearchField(
                    text: $viewModel.searchText,
                    isFocused: $viewModel.isSearchFieldFocused,
                    placeholder: "Search",
                    controlBackground: controlBackground,
                    borderColor: borderColor,
                    height: ExplorerSidebarConstants.bottomControlHeight
                )
                .frame(maxWidth: .infinity)

                if let session = selectedSession,
                   let structure = session.databaseStructure,
                   let database = selectedDatabase(in: structure, for: session),
                   !viewModel.isSearchFieldFocused {
                    let connID = session.connection.id
                    let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent
                    let creationOptions = creationOptions(for: session.connection.databaseType)

                    if !creationOptions.isEmpty {
                        addButton(options: creationOptions, accentColor: accentColor, session: session, database: database)
                    }

                    schemaPicker(database: database, connID: connID, accentColor: accentColor, controlBackground: controlBackground, borderColor: borderColor)
                }
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func addButton(options: [ExplorerCreationMenuItem], accentColor: Color, session: ConnectionSession, database: DatabaseInfo) -> some View {
        Menu {
            ForEach(options, id: \.title) { item in
                Button {
                    handleCreationAction(item, session: session, database: database)
                } label: {
                    Label {
                        Text(item.title)
                    } icon: {
                        item.iconView(accentColor: accentColor)
                    }
                }
            }
        } label: {
            ExplorerFooterActionButton(accentColor: accentColor)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .menuIndicator(.hidden)
        .transition(
            .scale(scale: 0.95, anchor: .trailing)
                .combined(with: .opacity)
        )
    }

    func handleCreationAction(_ item: ExplorerCreationMenuItem, session: ConnectionSession, database: DatabaseInfo) {
        switch item.title {
        case "New Extension":
            environmentState.openExtensionsManagerTab(connectionID: session.connection.id, databaseName: database.name)
        case "New Schema":
            let sql = creationTemplateSQL(for: item.title, databaseType: session.connection.databaseType, schemaName: nil)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database.name)
        default:
            let schemaName = resolvedSchemaName(for: session, database: database)
            let sql = creationTemplateSQL(for: item.title, databaseType: session.connection.databaseType, schemaName: schemaName)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database.name)
        }
    }

    private func resolvedSchemaName(for session: ConnectionSession, database: DatabaseInfo) -> String {
        let schemaKey = "\(session.connection.id.uuidString)#\(database.name)"
        if let selected = viewModel.selectedSchemaNameBySession[schemaKey] {
            return selected
        }
        switch session.connection.databaseType {
        case .postgresql: return "public"
        case .microsoftSQL: return "dbo"
        case .mysql, .sqlite: return ""
        }
    }

    @ViewBuilder
    private func schemaPicker(database: DatabaseInfo, connID: UUID, accentColor: Color, controlBackground: Color, borderColor: Color) -> some View {
        let availableSchemas = database.schemas.filter { !$0.objects.isEmpty }
        let schemaKey = "\(connID.uuidString)#\(database.name)"
        let currentSchemaSelection = viewModel.selectedSchemaNameBySession[schemaKey]

        if !availableSchemas.isEmpty {
            let schemaDisplayName: String = {
                if let schemaName = currentSchemaSelection { return schemaName }
                if availableSchemas.count == 1, let only = availableSchemas.first?.name { return only }
                return "All Schemas"
            }()

            Menu {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = viewModel.selectedSchemaNameBySession.removeValue(forKey: schemaKey)
                    }
                } label: {
                    if currentSchemaSelection == nil {
                        Label("All Schemas", systemImage: "checkmark")
                    } else {
                        Text("All Schemas")
                    }
                }

                ForEach(availableSchemas, id: \.name) { schema in
                    let objectCount = schema.objects.count
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedSchemaNameBySession[schemaKey] = schema.name
                        }
                    } label: {
                        if currentSchemaSelection == schema.name {
                            Label { Text("\(schema.name) (\(objectCount))") } icon: { Image(systemName: "checkmark") }
                        } else {
                            Text("\(schema.name) (\(objectCount))")
                        }
                    }
                }
            } label: {
                HStack(spacing: SpacingTokens.xs) {
                    Image("schema")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(currentSchemaSelection == nil ? ColorTokens.Text.secondary : accentColor)

                    Text(schemaDisplayName)
                        .font(TypographyTokens.caption2)
                        .lineLimit(1)
                        .foregroundStyle(currentSchemaSelection == nil ? ColorTokens.Text.primary : accentColor)
                }
                .padding(.horizontal, SpacingTokens.xs2)
                .padding(.vertical, SpacingTokens.xxs)
                .frame(minWidth: 132, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(borderColor, lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .transition(.opacity)
        }
    }

}
