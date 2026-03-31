import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AuthState.self) private var authState

    private var updater = SparkleUpdater.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private var automaticUpdatesBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.setAutomaticallyChecksForUpdates($0) }
        )
    }

    var body: some View {
        Form {
            accountSection
            softwareUpdateSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        if authState.isSignedIn {
            SignedInAccountCard(authState: authState)
        } else {
            SignInAccountCard(authState: authState)
        }
    }

    // MARK: - Software Update

    private var softwareUpdateSection: some View {
        Section("Software Update") {
            PropertyRow(title: "Installed") {
                Text("Echo \(appVersion) (\(buildNumber))")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            PropertyRow(title: "Check for updates") {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Text("Check for Updates")
                }
                .disabled(!updater.canCheckForUpdates)
            }

            PropertyRow(
                title: "Automatic Updates",
                info: "When enabled, Echo periodically checks for new versions in the background and notifies you when an update is available."
            ) {
                Toggle("", isOn: automaticUpdatesBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
