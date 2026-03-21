import AppKit
import SwiftUI

extension TableStructureEditorView {

    internal var accentNSColor: NSColor {
        if projectStore.globalSettings.accentColorSource == .connection {
            return NSColor(tab.connection.color)
        }
        return NSColor.controlAccentColor
    }

    internal var accentColor: Color { Color(nsColor: accentNSColor) }
}
