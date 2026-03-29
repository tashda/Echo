import Foundation

extension EnvironmentState {
    // MARK: - Editor Windows

    @discardableResult
    func prepareLoginEditorWindow(
        connectionSessionID: UUID,
        existingLogin: String?
    ) -> LoginEditorWindowValue {
        let value = LoginEditorWindowValue(
            connectionSessionID: connectionSessionID,
            existingLoginName: existingLogin
        )
        if loginEditorViewModels[value] == nil {
            loginEditorViewModels[value] = LoginEditorViewModel(
                connectionSessionID: connectionSessionID,
                existingLoginName: existingLogin
            )
        }
        activeLoginEditorValue = value
        return value
    }

    @discardableResult
    func prepareUserEditorWindow(
        connectionSessionID: UUID,
        database: String,
        existingUser: String?
    ) -> UserEditorWindowValue {
        let value = UserEditorWindowValue(
            connectionSessionID: connectionSessionID,
            databaseName: database,
            existingUserName: existingUser
        )
        if userEditorViewModels[value] == nil {
            let vm = UserEditorViewModel(
                connectionSessionID: connectionSessionID,
                databaseName: database,
                existingUserName: existingUser
            )
            userEditorViewModels[value] = vm
        }
        activeUserEditorValue = value
        return value
    }

    @discardableResult
    func prepareRoleEditorWindow(
        connectionSessionID: UUID,
        database: String,
        existingRole: String?
    ) -> RoleEditorWindowValue {
        let value = RoleEditorWindowValue(
            connectionSessionID: connectionSessionID,
            databaseName: database,
            existingRoleName: existingRole
        )
        if roleEditorViewModels[value] == nil {
            let vm = RoleEditorViewModel(
                connectionSessionID: connectionSessionID,
                databaseName: database,
                existingRoleName: existingRole
            )
            roleEditorViewModels[value] = vm
        }
        activeRoleEditorValue = value
        return value
    }

    @discardableResult
    func prepareDatabaseEditorWindow(
        connectionSessionID: UUID,
        databaseName: String,
        databaseType: DatabaseType
    ) -> DatabaseEditorWindowValue {
        let value = DatabaseEditorWindowValue(
            connectionSessionID: connectionSessionID,
            databaseName: databaseName
        )
        // Reuse existing ViewModel if the window is already open — avoids
        // replacing a loaded ViewModel with a fresh one stuck at isLoading.
        if databaseEditorViewModels[value] == nil {
            databaseEditorViewModels[value] = DatabaseEditorViewModel(
                connectionSessionID: connectionSessionID,
                databaseName: databaseName,
                databaseType: databaseType
            )
        }
        activeDatabaseEditorValue = value
        return value
    }

    @discardableResult
    func prepareServerEditorWindow(
        connectionSessionID: UUID
    ) -> ServerEditorWindowValue {
        let value = ServerEditorWindowValue(connectionSessionID: connectionSessionID)
        if serverEditorViewModels[value] == nil {
            serverEditorViewModels[value] = ServerEditorViewModel(connectionSessionID: connectionSessionID)
        }
        activeServerEditorValue = value
        return value
    }

    @discardableResult
    func preparePgRoleEditorWindow(
        connectionSessionID: UUID,
        existingRole: String?
    ) -> PgRoleEditorWindowValue {
        let value = PgRoleEditorWindowValue(
            connectionSessionID: connectionSessionID,
            roleName: existingRole
        )
        if pgRoleEditorViewModels[value] == nil {
            pgRoleEditorViewModels[value] = PgRoleEditorViewModel(
                connectionSessionID: connectionSessionID,
                existingRoleName: existingRole
            )
        }
        activePgRoleEditorValue = value
        return value
    }

    @discardableResult
    func prepareFunctionEditorWindow(
        connectionSessionID: UUID,
        schemaName: String,
        existingFunction: String?
    ) -> FunctionEditorWindowValue {
        let value = FunctionEditorWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            functionName: existingFunction
        )
        if functionEditorViewModels[value] == nil {
            functionEditorViewModels[value] = FunctionEditorViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                existingFunctionName: existingFunction
            )
        }
        activeFunctionEditorValue = value
        return value
    }

    @discardableResult
    func preparePublicationEditorWindow(
        connectionSessionID: UUID,
        existingPublication: String?
    ) -> PublicationEditorWindowValue {
        let value = PublicationEditorWindowValue(
            connectionSessionID: connectionSessionID,
            publicationName: existingPublication
        )
        if publicationEditorViewModels[value] == nil {
            publicationEditorViewModels[value] = PublicationEditorViewModel(
                connectionSessionID: connectionSessionID,
                existingPublicationName: existingPublication
            )
        }
        activePublicationEditorValue = value
        return value
    }

    @discardableResult
    func prepareSubscriptionEditorWindow(
        connectionSessionID: UUID,
        existingSubscription: String?
    ) -> SubscriptionEditorWindowValue {
        let value = SubscriptionEditorWindowValue(
            connectionSessionID: connectionSessionID,
            subscriptionName: existingSubscription
        )
        if subscriptionEditorViewModels[value] == nil {
            subscriptionEditorViewModels[value] = SubscriptionEditorViewModel(
                connectionSessionID: connectionSessionID,
                existingSubscriptionName: existingSubscription
            )
        }
        activeSubscriptionEditorValue = value
        return value
    }

    @discardableResult
    func preparePermissionManagerWindow(
        connectionSessionID: UUID,
        databaseName: String,
        principalName: String?
    ) -> PermissionManagerWindowValue {
        let value = PermissionManagerWindowValue(
            connectionSessionID: connectionSessionID,
            databaseName: databaseName,
            principalName: principalName
        )
        if permissionManagerViewModels[value] == nil {
            permissionManagerViewModels[value] = PermissionManagerViewModel(
                connectionSessionID: connectionSessionID,
                databaseName: databaseName,
                principalName: principalName
            )
        }
        activePermissionManagerValue = value
        return value
    }

    @discardableResult
    func prepareTablePropertiesWindow(
        connectionSessionID: UUID,
        schemaName: String,
        tableName: String,
        databaseType: DatabaseType
    ) -> TablePropertiesWindowValue {
        let value = TablePropertiesWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            tableName: tableName
        )
        if tablePropertiesViewModels[value] == nil {
            tablePropertiesViewModels[value] = TablePropertiesViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                tableName: tableName,
                databaseType: databaseType
            )
        }
        activeTablePropertiesValue = value
        return value
    }

    // MARK: - Trigger Editor

    @discardableResult
    func prepareTriggerEditorWindow(
        connectionSessionID: UUID,
        schemaName: String,
        tableName: String,
        existingTrigger: String?
    ) -> TriggerEditorWindowValue {
        let value = TriggerEditorWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            tableName: tableName,
            triggerName: existingTrigger
        )
        if triggerEditorViewModels[value] == nil {
            triggerEditorViewModels[value] = TriggerEditorViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                tableName: tableName,
                existingTriggerName: existingTrigger
            )
        }
        activeTriggerEditorValue = value
        return value
    }

    // MARK: - View Editor

    @discardableResult
    func prepareViewEditorWindow(
        connectionSessionID: UUID,
        schemaName: String,
        existingView: String?,
        isMaterialized: Bool
    ) -> ViewEditorWindowValue {
        let value = ViewEditorWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            viewName: existingView,
            isMaterialized: isMaterialized
        )
        if viewEditorViewModels[value] == nil {
            viewEditorViewModels[value] = ViewEditorViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                existingViewName: existingView,
                isMaterialized: isMaterialized
            )
        }
        activeViewEditorValue = value
        return value
    }

    // MARK: - Sequence Editor

    @discardableResult
    func prepareSequenceEditorWindow(
        connectionSessionID: UUID,
        schemaName: String,
        existingSequence: String?
    ) -> SequenceEditorWindowValue {
        let value = SequenceEditorWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            sequenceName: existingSequence
        )
        if sequenceEditorViewModels[value] == nil {
            sequenceEditorViewModels[value] = SequenceEditorViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                existingSequenceName: existingSequence
            )
        }
        activeSequenceEditorValue = value
        return value
    }

    // MARK: - Type Editor

    @discardableResult
    func prepareTypeEditorWindow(
        connectionSessionID: UUID,
        schemaName: String,
        existingType: String?,
        typeCategory: TypeCategory
    ) -> TypeEditorWindowValue {
        let value = TypeEditorWindowValue(
            connectionSessionID: connectionSessionID,
            schemaName: schemaName,
            typeName: existingType,
            typeCategory: typeCategory
        )
        if typeEditorViewModels[value] == nil {
            typeEditorViewModels[value] = TypeEditorViewModel(
                connectionSessionID: connectionSessionID,
                schemaName: schemaName,
                existingTypeName: existingType,
                typeCategory: typeCategory
            )
        }
        activeTypeEditorValue = value
        return value
    }
}
