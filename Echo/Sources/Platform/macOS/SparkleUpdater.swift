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
    enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate(message: String)
        case updateAvailable(version: String)
        case error(message: String)
    }

    var canCheckForUpdates = false
    var automaticallyChecksForUpdates = false
    var lastError: Error?
    var showErrorAlert = false
    var status: UpdateStatus = .idle

    #if canImport(Sparkle)
    @ObservationIgnored private var updaterController: SPUStandardUpdaterController?
    #endif

    static let shared = SparkleUpdater()

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
        #if canImport(Sparkle)
        // Skip Sparkle entirely when running under xctest
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

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

    func checkForUpdatesFromSettings() {
        guard canCheckForUpdates else { return }
        status = .checking
        lastError = nil
        showErrorAlert = false
        #if canImport(Sparkle)
        updaterController?.updater.checkForUpdateInformation()
        #endif
    }

    func installAvailableUpdate() {
        checkForUpdates()
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
        return "https://github.com/tashda/Echo/releases/latest/download/appcast.xml"
    }

    @objc func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.status = .updateAvailable(version: item.displayVersionString)
        }
    }

    @objc func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let message = SparkleUpdater.messageForNoUpdate(error)
        Task { @MainActor in
            self.status = .upToDate(message: message)
        }
    }

    @objc func versionComparator(for updater: SPUUpdater) -> (any SUVersionComparison)? {
        SparkleVersionComparator()
    }

    @objc func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        let currentVersion = InstalledAppVersion.current

        let bestMatch = appcast.items
            .filter { currentVersion.isUpdateAvailable(from: $0.displayVersionString, buildVersion: $0.versionString) }
            .max { lhs, rhs in
                InstalledAppVersion.isRemoteVersion(
                    rhs.displayVersionString,
                    buildVersion: rhs.versionString,
                    newerThan: lhs.displayVersionString,
                    buildVersion: lhs.versionString
                )
            }

        return bestMatch ?? SUAppcastItem.empty()
    }

    @objc func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            self.lastError = error
            let nsError = error as NSError
            if nsError.domain == SUSparkleErrorDomain {
                if nsError.code == 4007 || nsError.code == 1001 {
                    return
                }
            }
            if nsError.domain == "org.sparkle-project.Sparkle" && nsError.code == 4001 {
                return
            }
            self.status = .error(message: error.localizedDescription)
            self.showErrorAlert = true
        }
    }

    @objc func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard updateCheck == .updateInformation else { return }

        Task { @MainActor in
            if case .checking = self.status {
                if let error {
                    self.status = .error(message: error.localizedDescription)
                } else {
                    self.status = .idle
                }
            }
        }
    }
}
#endif

struct InstalledAppVersion: Equatable {
    let shortVersion: String
    let buildVersion: String

    static var current: Self {
        let infoDictionary = Bundle.main.infoDictionary
        return Self(
            shortVersion: infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            buildVersion: infoDictionary?["CFBundleVersion"] as? String ?? "0"
        )
    }

    func isUpdateAvailable(from remoteShortVersion: String, buildVersion remoteBuildVersion: String) -> Bool {
        Self.isRemoteVersion(
            remoteShortVersion,
            buildVersion: remoteBuildVersion,
            newerThan: shortVersion,
            buildVersion: buildVersion
        )
    }

    static func isRemoteVersion(
        _ remoteShortVersion: String,
        buildVersion remoteBuildVersion: String,
        newerThan localShortVersion: String,
        buildVersion localBuildVersion: String
    ) -> Bool {
        let shortVersionComparison = compareVersionString(remoteShortVersion, to: localShortVersion)
        if shortVersionComparison != .orderedSame {
            return shortVersionComparison == .orderedDescending
        }

        return compareVersionString(remoteBuildVersion, to: localBuildVersion) == .orderedDescending
    }

    static func compareVersionString(_ lhs: String, to rhs: String) -> ComparisonResult {
        let leftParts = numericComponents(in: lhs)
        let rightParts = numericComponents(in: rhs)
        let maxCount = max(leftParts.count, rightParts.count)

        guard maxCount > 0 else {
            return lhs.localizedStandardCompare(rhs)
        }

        for index in 0..<maxCount {
            let leftPart = index < leftParts.count ? leftParts[index] : 0
            let rightPart = index < rightParts.count ? rightParts[index] : 0

            if leftPart < rightPart { return .orderedAscending }
            if leftPart > rightPart { return .orderedDescending }
        }

        return .orderedSame
    }

    static func numericComponents(in versionString: String) -> [Int] {
        versionString
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

#if canImport(Sparkle)
private final class SparkleVersionComparator: NSObject, SUVersionComparison {
    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        InstalledAppVersion.isRemoteVersion(
            versionB,
            buildVersion: "0",
            newerThan: versionA,
            buildVersion: "0"
        ) ? .orderedAscending :
        InstalledAppVersion.isRemoteVersion(
            versionA,
            buildVersion: "0",
            newerThan: versionB,
            buildVersion: "0"
        ) ? .orderedDescending : .orderedSame
    }
}

private extension SparkleUpdater {
    static func messageForNoUpdate(_ error: Error) -> String {
        let nsError = error as NSError
        guard
            nsError.domain == SUSparkleErrorDomain,
            let reasonValue = nsError.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber,
            let reason = SPUNoUpdateFoundReason(rawValue: OSStatus(reasonValue.int32Value))
        else {
            return "Echo is up to date."
        }

        switch reason {
        case .onLatestVersion:
            return "Echo is up to date."
        case .onNewerThanLatestVersion:
            return "This build is newer than the latest published release."
        case .systemIsTooOld:
            return "A newer Echo release exists, but it requires a newer macOS version."
        case .systemIsTooNew:
            return "The latest published release does not support this macOS version yet."
        case .hardwareDoesNotSupportARM64:
            return "A newer Echo release exists, but it requires Apple silicon."
        case .unknown:
            return "Echo is up to date."
        @unknown default:
            return "Echo is up to date."
        }
    }
}
#endif
