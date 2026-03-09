import SwiftUI

#if os(macOS)
import AppKit

extension DatabaseObjectRow {
    @MainActor
    internal func presentTruncatePrompt() async {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(connection.id) else { return }

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
    internal func applyAppearance(to alert: NSAlert) {
        let scheme = AppearanceStore.shared.effectiveColorScheme
        if scheme == .dark {
            alert.window.appearance = NSAppearance(named: .darkAqua)
        } else {
            alert.window.appearance = NSAppearance(named: .aqua)
        }
    }
}
#endif
