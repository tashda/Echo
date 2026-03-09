import Combine
import Foundation
import SwiftUI

#if canImport(Sparkle)
import Sparkle
#endif

/// A simple wrapper around Sparkle's SPUUpdater to provide auto-update functionality.
@MainActor
final class SparkleUpdater: ObservableObject {
    @Published var canCheckForUpdates = false

    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    #endif

    static let shared = SparkleUpdater()

    private init() {
        #if canImport(Sparkle)
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
        #endif
    }
}
