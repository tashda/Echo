import SwiftUI

#if os(macOS)
import AppKit

extension DatabaseObjectRow {
    @MainActor
    internal func presentRenamePrompt() async {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
        
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
                await environmentState.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.selectedDatabaseName
                )
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                }
            }
        }
    }

    @MainActor
    internal func presentDropPrompt(includeIfExists: Bool) async {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }
        
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
                await environmentState.refreshDatabaseStructure(
                    for: session.id,
                    scope: .selectedDatabase,
                    databaseOverride: session.selectedDatabaseName
                )
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
}
#endif
