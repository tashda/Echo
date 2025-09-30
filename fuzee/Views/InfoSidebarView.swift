import SwiftUI

struct InfoSidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Info")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()
                .opacity(0.3)

            // Content area - empty for now
            ScrollView {
                VStack(spacing: 16) {
                    Text("Info Sidebar")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("This sidebar is available globally and can display information from anywhere in the application.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .frame(minWidth: 200, idealWidth: 280, maxWidth: 400)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    InfoSidebarView()
        .environmentObject(AppModel())
        .environmentObject(AppState())
}