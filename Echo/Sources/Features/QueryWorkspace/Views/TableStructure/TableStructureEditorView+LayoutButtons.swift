import AppKit
import SwiftUI

// Accent color and button helpers are now in LayoutHelpers.
// This file is kept for the data type menu support in the ColumnEditorSheet.

extension TableStructureEditorView {

    internal var inlineButtonBackground: Color {
        ColorTokens.Background.secondary.opacity(0.2)
    }
}
