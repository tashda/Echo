import SwiftUI
import Combine

final class TopBarNavigatorLayoutState: ObservableObject {
    @Published private(set) var availableWidth: CGFloat = 0
    @Published private(set) var centerX: CGFloat = 0
    @Published private(set) var toolbarWidth: CGFloat = 0

    func update(availableWidth: CGFloat, centerX: CGFloat, toolbarWidth: CGFloat) {
        if abs(self.availableWidth - availableWidth) > 0.5 {
            self.availableWidth = availableWidth
        }
        if abs(self.centerX - centerX) > 0.5 {
            self.centerX = centerX
        }
        if abs(self.toolbarWidth - toolbarWidth) > 0.5 {
            self.toolbarWidth = toolbarWidth
        }
    }
}
