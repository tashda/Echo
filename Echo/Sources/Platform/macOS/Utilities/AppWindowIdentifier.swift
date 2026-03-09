#if os(macOS)
import AppKit

enum AppWindowIdentifier {
    static let workspace = NSUserInterfaceItemIdentifier("workspace-window")
    static let settings = NSUserInterfaceItemIdentifier("settings-window")
    static let manageConnections = NSUserInterfaceItemIdentifier("manage-connections-window")
    static let manageProjects = NSUserInterfaceItemIdentifier("manage-projects-window")
}
#endif
