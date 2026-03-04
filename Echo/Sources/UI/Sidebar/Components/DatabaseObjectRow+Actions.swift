import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func performScriptAction(_ action: ScriptAction) {
        switch action {
        case .create:
            if object.type == .table {
                openCreateTableScript()
            } else {
                openCreateDefinition(insertOrReplace: false)
            }
        case .createOrReplace:
            openCreateDefinition(insertOrReplace: true)
        case .alter:
            openAlterStatement()
        case .alterTable:
            openAlterTableStatement()
        case .drop:
            openDropStatement(includeIfExists: false)
        case .dropIfExists:
            openDropStatement(includeIfExists: true)
        case .select:
            openSelectScript(limit: nil)
        case .selectLimited(let limit):
            openSelectScript(limit: limit)
        case .execute:
            openExecuteScript()
        }
    }
    
    internal func openNewQueryTab() {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let sql = "-- Query for \(qualified)\n"
        Task { @MainActor in
            appModel.openQueryTab(for: session, presetQuery: sql)
        }
    }
    
    internal func openDataPreview() {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let columns = object.columns.isEmpty ? ["*"] : object.columns.map { quoteIdentifier($0.name) }
        let columnLines = columns.joined(separator: ",\n    ")
        let databaseType = connection.databaseType
        let sql = makeSelectStatement(
            qualifiedName: qualified,
            columnLines: columnLines,
            databaseType: databaseType,
            limit: 200,
            offset: 0
        )
        Task { @MainActor in
            appModel.openQueryTab(for: session, presetQuery: sql)
        }
    }
    
    internal func openStructureTab() {
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            appModel.openStructureTab(for: session, object: object)
        }
    }
    
    internal func openRelationsDiagram() {
        guard supportsDiagram else { return }
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            appModel.openDiagramTab(for: session, object: object)
        }
    }
    
    internal func openCreateDefinition(insertOrReplace: Bool) {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type
                )
                let adjusted = insertOrReplace ? applyCreateOrReplace(to: definition) : definition
                await MainActor.run {
                    appModel.openQueryTab(for: session, presetQuery: adjusted)
                }
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
    internal func openCreateTableScript() {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        Task {
            do {
                let details = try await session.session.getTableStructureDetails(
                    schema: object.schema,
                    table: object.name
                )
                let script = makeCreateTableScript(details: details)
                await MainActor.run {
                    appModel.openQueryTab(for: session, presetQuery: script)
                }
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
    private func applyCreateOrReplace(to definition: String) -> String {
        guard let range = definition.range(of: "CREATE", options: [.caseInsensitive]) else {
            return definition
        }
        let snippet = definition[range]
        if snippet.lowercased().contains("create or replace") {
            return definition
        }
        return definition.replacingCharacters(in: range, with: "CREATE OR REPLACE")
    }
    
    internal func openAlterStatement() {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let statement: String
        switch connection.databaseType {
        case .mysql:
            switch object.type {
            case .function, .procedure:
                statement = "ALTER FUNCTION \(qualified)\n    -- Update characteristics here;\n"
            case .trigger:
                statement = "ALTER TRIGGER \(qualified)\n    -- Update trigger definition here;\n"
            default:
                statement = "ALTER \(objectTypeKeyword()) \(qualified)\n    -- Provide ALTER clauses here;\n"
            }
        case .microsoftSQL:
            statement = """
        ALTER \(objectTypeKeyword()) \(qualified)
        -- Update definition here.
        GO
        """
        case .postgresql, .sqlite:
            statement = """
        -- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE.
        """
        }
        openScriptTab(with: statement)
    }
    
    internal func openAlterTableStatement() {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let statement: String
        switch connection.databaseType {
        case .postgresql, .mysql:
            statement = """
        ALTER TABLE \(qualified)
            ADD COLUMN new_column_name data_type;
        """
        case .microsoftSQL:
            statement = """
        ALTER TABLE \(qualified)
            ADD new_column_name data_type;
        """
        case .sqlite:
            statement = """
        ALTER TABLE \(qualified)
            RENAME COLUMN old_column TO new_column;
        """
        }
        openScriptTab(with: statement)
    }
    
    internal func openDropStatement(includeIfExists: Bool) {
        let statement = dropStatement(includeIfExists: includeIfExists)
        openScriptTab(with: statement)
    }
    
    internal func openSelectScript(limit: Int? = nil) {
        let sql: String
        if object.type == .function || object.type == .procedure {
            sql = executeStatement()
        } else {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let columns = object.columns.isEmpty ? ["*"] : object.columns.map { quoteIdentifier($0.name) }
            let columnLines = columns.joined(separator: ",\n    ")
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: columnLines,
                databaseType: connection.databaseType,
                limit: limit
            )
        }
        openScriptTab(with: sql)
    }
    
    internal func openExecuteScript() {
        let sql = executeStatement()
        openScriptTab(with: sql)
    }
    
    internal func initiateTruncate() {
#if os(macOS)
        if object.type == .table {
            Task { await presentTruncatePrompt() }
            return
        }
#endif
        let statement = truncateStatement()
        openScriptTab(with: statement)
    }
    
    internal func initiateRename() {
#if os(macOS)
        Task { await presentRenamePrompt() }
#else
        if let template = renameStatement() {
            openScriptTab(with: template)
        }
#endif
    }
    
#if os(macOS)
    @MainActor
    internal func presentRenamePrompt() async {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        
        let alert = NSAlert()
        alert.icon = NSImage(size: .zero)
        alert.messageText = "Rename \(objectTypeDisplayName())"
        alert.alertStyle = .informational
        alert.informativeText = ""
        applyAppearance(to: alert)
        
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        
        let message = NSMutableAttributedString(string: "Enter a new name for the \(objectTypeDisplayName().lowercased()) ", attributes: [
            .font: baseFont
        ])
        message.append(NSAttributedString(string: object.fullName, attributes: [
            .font: boldFont
        ]))
        message.append(NSAttributedString(string: ".", attributes: [
            .font: baseFont
        ]))
        
        let messageLabel = NSTextField(labelWithAttributedString: message)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = 320
        messageLabel.alignment = .center
        
        let textField = NSTextField(string: object.name)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 8
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(textField)
        stack.setHuggingPriority(.defaultHigh, for: .vertical)
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        
        alert.accessoryView = stack
        alert.window.initialFirstResponder = textField
        textField.selectText(nil)
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != object.name else { return }
        
        guard let sql = renameStatement(newName: newName) else {
            if let template = renameStatement() {
                openScriptTab(with: template)
            }
            return
        }
        
        connectionStore.selectedConnectionID = session.connection.id
        
        Task {
            do {
                _ = try await session.session.executeUpdate(sql)
                await appModel.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.selectedDatabaseName
                )
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
#endif
    
    internal func initiateDrop(includeIfExists: Bool) {
#if os(macOS)
        if object.type == .table {
            Task { await presentDropPrompt(includeIfExists: includeIfExists) }
            return
        }
#endif
        let statement = dropStatement(includeIfExists: includeIfExists)
        openScriptTab(with: statement)
    }
    
#if os(macOS)
    @MainActor
    internal func presentDropPrompt(includeIfExists: Bool) async {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        
        let alert = NSAlert()
        alert.icon = NSImage(size: .zero)
        alert.messageText = "Drop \(objectTypeDisplayName())"
        alert.alertStyle = .warning
        alert.informativeText = ""
        applyAppearance(to: alert)
        
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        
        let message = NSMutableAttributedString()
        message.append(NSAttributedString(string: "Are you sure you want to drop the \(objectTypeDisplayName().lowercased()) ", attributes: [
            .font: baseFont
        ]))
        message.append(NSAttributedString(string: object.fullName, attributes: [
            .font: boldFont
        ]))
        message.append(NSAttributedString(string: "?\nThis action cannot be undone.", attributes: [
            .font: baseFont
        ]))
        
        let messageLabel = NSTextField(labelWithAttributedString: message)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = 320
        messageLabel.alignment = .center
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 6
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        stack.addArrangedSubview(messageLabel)
        stack.setHuggingPriority(.required, for: .vertical)
        stack.setHuggingPriority(.required, for: .horizontal)
        
        alert.accessoryView = stack
        
        let dropButton = alert.addButton(withTitle: "Drop")
        if #available(macOS 11.0, *) {
            dropButton.hasDestructiveAction = true
        }
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let statement = dropStatement(includeIfExists: includeIfExists)
        
        connectionStore.selectedConnectionID = session.connection.id
        
        Task {
            do {
                _ = try await session.session.executeUpdate(statement)
                if isPinned {
                    await MainActor.run {
                        onTogglePin()
                    }
                }
                await appModel.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.selectedDatabaseName
                )
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
    @MainActor
    internal func presentTruncatePrompt() async {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        
        let alert = NSAlert()
        alert.icon = NSImage(size: .zero)
        alert.messageText = "Truncate \(objectTypeDisplayName())"
        alert.alertStyle = .warning
        alert.informativeText = ""
        applyAppearance(to: alert)
        
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        
        let message = NSMutableAttributedString()
        message.append(NSAttributedString(string: "Are you sure you want to truncate the \(objectTypeDisplayName().lowercased()) ", attributes: [
            .font: baseFont
        ]))
        message.append(NSAttributedString(string: object.fullName, attributes: [
            .font: boldFont
        ]))
        message.append(NSAttributedString(string: "?\nThis action cannot be undone.", attributes: [
            .font: baseFont
        ]))
        
        let messageLabel = NSTextField(labelWithAttributedString: message)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = 320
        messageLabel.alignment = .center
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 6
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        stack.addArrangedSubview(messageLabel)
        stack.setHuggingPriority(.required, for: .vertical)
        stack.setHuggingPriority(.required, for: .horizontal)
        
        alert.accessoryView = stack
        
        let truncateButton = alert.addButton(withTitle: "Truncate")
        if #available(macOS 11.0, *) {
            truncateButton.hasDestructiveAction = true
        }
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let statement = truncateStatement()
        
        connectionStore.selectedConnectionID = session.connection.id
        
        Task {
            do {
                _ = try await session.session.executeUpdate(statement)
                await appModel.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.selectedDatabaseName
                )
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
#endif
    
    internal func openScriptTab(with sql: String) {
        guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
        Task { @MainActor in
            appModel.openQueryTab(for: session, presetQuery: sql)
        }
    }
    
#if os(macOS)
    @MainActor
    internal func applyAppearance(to alert: NSAlert) {
        let scheme = ThemeManager.shared.effectiveColorScheme
        if scheme == .dark {
            alert.window.appearance = NSAppearance(named: .darkAqua)
        } else {
            alert.window.appearance = NSAppearance(named: .aqua)
        }
    }
#endif
}
