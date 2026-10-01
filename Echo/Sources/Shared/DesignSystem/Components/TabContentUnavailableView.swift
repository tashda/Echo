import SwiftUI

/// A native unavailable-content presentation that always occupies and centers
/// itself within the complete workspace-tab content area.
struct TabContentUnavailableView<Description: View, Actions: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let description: () -> Description
    @ViewBuilder let actions: () -> Actions

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder description: @escaping () -> Description,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            description()
        } actions: {
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension TabContentUnavailableView where Actions == EmptyView {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder description: @escaping () -> Description
    ) {
        self.init(title, systemImage: systemImage, description: description) {
            EmptyView()
        }
    }
}
