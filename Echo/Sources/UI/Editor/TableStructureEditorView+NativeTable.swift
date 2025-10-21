import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Native macOS Table Implementation

extension TableStructureEditorView {
    
    @ViewBuilder
    var adaptiveColumnsTable: some View {
        // Use the ORIGINAL working implementation
        columnsTable
    }
}
