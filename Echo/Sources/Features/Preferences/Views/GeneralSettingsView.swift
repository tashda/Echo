import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var updater = SparkleUpdater.shared

    var body: some View {
        Form {
            Section("Software Updates") {
                HStack(alignment: .top, spacing: SpacingTokens.md) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 32))
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        Text("Echo Updates")
                            .font(TypographyTokens.headline)
                        Text("Stay up to date with the latest improvements and bug fixes.")
                            .font(TypographyTokens.standard)
                            .foregroundStyle(.secondary)

                        Spacer().frame(height: SpacingTokens.xs)

                        Button {
                            updater.checkForUpdates()
                        } label: {
                            Text("Check for Updates…")
                        }
                        .disabled(!updater.canCheckForUpdates)
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
