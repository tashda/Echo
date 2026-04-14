import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AuthState.self) private var authState

    @Bindable private var updater = SparkleUpdater.shared

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
            SignedInAccountCard(authState: authState, syncEngine: AppDirector.shared.syncEngine)
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

            PropertyRow(title: "Status") {
                Text(updateStatusText)
                    .foregroundStyle(updateStatusColor)
            }

            PropertyRow(title: "Check for updates") {
                Button {
                    if case .updateAvailable = updater.status {
                        updater.installAvailableUpdate()
                    } else {
                        updater.checkForUpdatesFromSettings()
                    }
                } label: {
                    Text(updateButtonTitle)
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

    private var updateStatusText: String {
        switch updater.status {
        case .idle:
            return "Check for updates to see whether a newer release is available."
        case .checking:
            return "Checking for updates…"
        case let .upToDate(message):
            return message
        case let .updateAvailable(version):
            return "Echo \(version) is available."
        case let .error(message):
            return message
        }
    }

    private var updateStatusColor: Color {
        switch updater.status {
        case .updateAvailable:
            return ColorTokens.Status.info
        case .error:
            return ColorTokens.Status.error
        default:
            return ColorTokens.Text.secondary
        }
    }

    private var updateButtonTitle: String {
        if case .updateAvailable = updater.status {
            return "Install Update"
        }

        return "Check for Updates"
    }
}
