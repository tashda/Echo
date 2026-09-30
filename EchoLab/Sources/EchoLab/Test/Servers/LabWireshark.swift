import AppKit

/// Opens a capture in the Wireshark app when it is installed, otherwise shows it in Finder.
enum LabWireshark {
    static let appURL = URL(fileURLWithPath: "/Applications/Wireshark.app")

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: appURL.path) }

    static func open(_ file: URL) {
        if isInstalled {
            NSWorkspace.shared.open([file], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
    }
}
