import Combine
import Foundation
import SwiftUI

#if canImport(Sparkle)
import Sparkle
#endif

/// A simple wrapper around Sparkle's SPUUpdater to provide auto-update functionality.
@Observable
@MainActor
final class SparkleUpdater: NSObject {
    var canCheckForUpdates = false
    var automaticallyChecksForUpdates = false
    var lastError: Error?
    var showErrorAlert = false

    #if canImport(Sparkle)
    @ObservationIgnored private var updaterController: SPUStandardUpdaterController?
    #endif

    static let shared = SparkleUpdater()

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        #if canImport(Sparkle)
        // Initialize the controller. We set startingUpdater to false to ensure delegate is ready.
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = controller

        // Listen for changes to canCheckForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
            .store(in: &cancellables)

        // Sync automaticallyChecksForUpdates
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.automaticallyChecksForUpdates = value
            }
            .store(in: &cancellables)

        // Start the updater
        controller.startUpdater()
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #endif
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        #if canImport(Sparkle)
        updaterController?.updater.automaticallyChecksForUpdates = enabled
        #endif
        automaticallyChecksForUpdates = enabled
    }
}

#if canImport(Sparkle)
extension SparkleUpdater: SPUUpdaterDelegate {
    @objc func feedURLString(for updater: SPUUpdater) -> String? {
        // Hardcode the feed URL to ensure it's never missing
        return "https://raw.githubusercontent.com/tashda/Echo/main/appcast.xml"
    }
    
    @objc func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            self.lastError = error
            // Only show alert for real errors, not user cancellation
            let nsError = error as NSError
            if nsError.domain == "org.sparkle-project.Sparkle" && nsError.code == 4001 { // User cancelled
                return
            }
            self.showErrorAlert = true
        }
    }
}
#endif
