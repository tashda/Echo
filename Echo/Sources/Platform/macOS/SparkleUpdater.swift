import Combine
import Foundation
import SwiftUI

#if canImport(Sparkle)
import Sparkle
#endif

/// A simple wrapper around Sparkle's SPUUpdater to provide auto-update functionality.
@MainActor
final class SparkleUpdater: NSObject, ObservableObject {
    @Published var canCheckForUpdates = false
    @Published var lastError: Error?
    @Published var showErrorAlert = false

    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif

    static let shared = SparkleUpdater()

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
        
        // Start the updater
        controller.startUpdater()
        #endif
    }
    
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #endif
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
