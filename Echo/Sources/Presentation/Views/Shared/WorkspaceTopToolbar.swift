import SwiftUI

struct WorkspaceTopToolbar: View {
    let availableWidth: CGFloat

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    private var navigatorWidth: CGFloat {
        let reservedSpace: CGFloat = 80
        let maxWidthCandidate = max(availableWidth - reservedSpace, 200)
        let maxWidth = min(maxWidthCandidate, availableWidth)
        let minWidth = min(320, maxWidth)
        let preferred = max(availableWidth * 0.6, minWidth)
        return min(preferred, maxWidth)
    }

    var body: some View {
        ZStack {
            HStack {
                Spacer(minLength: 0)
                TopBarNavigator(width: navigatorWidth)
                    .environmentObject(appModel)
                    .environmentObject(appModel.navigationState)
                    .frame(height: 32)
                Spacer(minLength: 0)
            }

            #if os(macOS)
            HStack {
                Spacer(minLength: 0)
                InspectorToggleButton(isActive: appState.showInfoSidebar) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showInfoSidebar.toggle()
                    }
                }
            }
            .frame(height: 32)
            #endif
        }
        .frame(height: 32)
    }
}
