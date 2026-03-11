import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var updater = SparkleUpdater.shared

    var body: some View {
        Form {
            Section("Software Updates") {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 32))
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Echo Updates")
                            .font(.headline)
                        Text("Stay up to date with the latest improvements and bug fixes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer().frame(height: 8)
                        
                        Button {
                            updater.checkForUpdates()
                        } label: {
                            Text("Check for Updates…")
                        }
                        .disabled(!updater.canCheckForUpdates)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
