import SwiftUI

extension EnvironmentValues {
    /// The tab a view's content belongs to (set by `WorkspaceContentView`). Tab content reads its
    /// own tab from here, not `TabStore.activeTab`: a tab kept mounted behind another one would
    /// show the other tab's server, and would re-render on every tab switch.
    @Entry var workspaceTab: WorkspaceTab?
}
