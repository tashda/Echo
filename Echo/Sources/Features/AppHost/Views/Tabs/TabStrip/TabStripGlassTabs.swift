import SwiftUI

extension EnvironmentValues {
    /// The glass tab bar (round 11, T1 with two lines): inactive tabs have no fill, full-strength
    /// titles and hairline dividers; every tab shows its kind's icon and two lines, the title over
    /// the database (or the timer while running). Off for the Classic strip.
    @Entry var tabStripUsesGlassTabs = false
}
