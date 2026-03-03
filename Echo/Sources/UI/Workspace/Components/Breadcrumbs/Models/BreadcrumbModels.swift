import SwiftUI
import Combine

/// Represents a single segment in the breadcrumb navigation
struct BreadcrumbSegment: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String?
    let hasMenu: Bool
    let isActive: Bool
    let isEnabled: Bool

    // Actions and menu content
    let action: (() -> Void)?
    let menuContent: (() -> AnyView)?

    init(
        title: String,
        icon: String? = nil,
        hasMenu: Bool = false,
        isActive: Bool = false,
        isEnabled: Bool = true,
        action: (() -> Void)? = nil,
        menuContent: (() -> AnyView)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.hasMenu = hasMenu
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.action = action
        self.menuContent = menuContent
    }

    static func == (lhs: BreadcrumbSegment, rhs: BreadcrumbSegment) -> Bool {
        return lhs.title == rhs.title &&
               lhs.icon == rhs.icon &&
               lhs.hasMenu == rhs.hasMenu &&
               lhs.isActive == rhs.isActive &&
               lhs.isEnabled == rhs.isEnabled
    }
}

/// State manager for breadcrumb navigation
@MainActor
class BreadcrumbNavigationState: ObservableObject {
    @Published var segments: [BreadcrumbSegment] = []
    @Published var isMenuPresented: Bool = false
    @Published var presentedMenuIndex: Int?

    func updateSegments(_ newSegments: [BreadcrumbSegment]) {
        segments = newSegments
    }

    func presentMenu(for index: Int) {
        presentedMenuIndex = index
        isMenuPresented = true
    }

    func dismissMenu() {
        isMenuPresented = false
        presentedMenuIndex = nil
    }
}
