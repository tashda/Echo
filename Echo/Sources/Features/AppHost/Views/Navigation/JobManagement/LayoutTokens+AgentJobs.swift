import SwiftUI

extension LayoutTokens {
    /// The Agent Jobs tab and its sheets (round 33).
    enum AgentJobs {
        /// The jobs list's Status column (JC1).
        static let statusColumnWidth: CGFloat = SpacingTokens.lg2
        /// New Step / Edit Step (round 33.2, NS4): the command at the left, the settings at the right.
        static let stepSheetMinWidth: CGFloat = 760
        static let stepSheetMinHeight: CGFloat = 480
        static let stepSidebarWidth: CGFloat = 300
        static let stepCommandMinHeight: CGFloat = SpacingTokens.xxxl * 3
    }
}
