import AppKit

/// A standard alert as a sheet on the key window (or on its own when there is none); returns the
/// index of the button that was pressed.
@MainActor
enum WindowAlert {
    struct Button {
        let title: String
        var isDestructive = false
    }

    static func present(title: String, message: String, buttons: [Button]) async -> Int {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        for button in buttons {
            alert.addButton(withTitle: button.title).hasDestructiveAction = button.isDestructive
        }
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await alert.beginSheetModal(for: window)
        } else {
            response = alert.runModal()
        }
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return min(max(index, 0), buttons.count - 1)
    }
}
