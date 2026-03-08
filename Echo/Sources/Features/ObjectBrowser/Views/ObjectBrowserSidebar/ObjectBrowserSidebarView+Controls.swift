import SwiftUI

extension ObjectBrowserSidebarView {
    var footerView: some View {
        Group {
            if let session = selectedSession,
               let structure = session.databaseStructure,
               let database = selectedDatabase(in: structure, for: session) {
                let hasExplorerContent = database.schemas.contains { !$0.objects.isEmpty }

                VStack(spacing: 0) {
                    Divider()
                        .opacity(hasExplorerContent ? 1 : 0)
                    footerControls(session: session, database: database)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyView()
            }
        }
    }

    func footerControls(
        session: ConnectionSession,
        database: DatabaseInfo
    ) -> some View {
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : Color.accentColor
        let controlBackground = Color.primary.opacity(0.04)
        let borderColor = Color.primary.opacity(0.08)
        let availableSchemas = database.schemas.filter { !$0.objects.isEmpty }
        let connID = session.connection.id
        let currentSchemaSelection = viewModel.selectedSchemaNameBySession[connID]
        let schemaDisplayName: String = {
            if let schemaName = currentSchemaSelection {
                return schemaName
            }
            if availableSchemas.count == 1, let onlySchema = availableSchemas.first?.name {
                return onlySchema
            }
            return "All Schemas"
        }()

        let shouldShowSchemaPicker = !availableSchemas.isEmpty && !viewModel.isSearchFieldFocused
        let creationOptions = creationOptions(for: session.connection.databaseType)
        let shouldShowAddButton = !viewModel.isSearchFieldFocused && !creationOptions.isEmpty

        return HStack(spacing: 6) {
            ExplorerFooterSearchField(
                text: $viewModel.searchText,
                isFocused: $viewModel.isSearchFieldFocused,
                placeholder: "Search",
                controlBackground: controlBackground,
                borderColor: borderColor,
                height: ExplorerSidebarConstants.bottomControlHeight
            )
            .frame(maxWidth: .infinity)

            if shouldShowAddButton {
                Menu {
                    ForEach(creationOptions, id: \.title) { item in
                        Button(action: {}) {
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

            if shouldShowSchemaPicker {
                Menu {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = viewModel.selectedSchemaNameBySession.removeValue(forKey: connID)
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
                                viewModel.selectedSchemaNameBySession[connID] = schema.name
                            }
                        } label: {
                            if currentSchemaSelection == schema.name {
                                Label {
                                    Text("\(schema.name) (\(objectCount))")
                                } icon: {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Text("\(schema.name) (\(objectCount))")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("schema")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(currentSchemaSelection == nil ? .secondary : accentColor)

                        Text(schemaDisplayName)
                            .font(TypographyTokens.caption2.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(currentSchemaSelection == nil ? Color.primary : accentColor)
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
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs2)
    }

}
