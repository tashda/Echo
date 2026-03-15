import SwiftUI

struct GeneralSettingsView: View {
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
            Section("Software Update") {
                LabeledContent("Installed") {
                    Text("Echo \(appVersion) (\(buildNumber))")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                Button {
                    updater.checkForUpdates()
                } label: {
                    Text("Check for Updates…")
                }
                .disabled(!updater.canCheckForUpdates)
            }

            Section {
                SettingsRowWithInfo(
                    title: "Automatic Updates",
                    description: "When enabled, Echo periodically checks for new versions in the background and notifies you when an update is available."
                ) {
                    Toggle("", isOn: automaticUpdatesBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
