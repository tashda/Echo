import Testing
@testable import Echo

@Suite("Sparkle Updater Versions")
struct SparkleUpdaterVersionTests {
    @Test func patchReleaseBeatsOlderShortVersionEvenWithLowerBuildNumber() {
        #expect(
            InstalledAppVersion.isRemoteVersion(
                "1.0.1",
                buildVersion: "1",
                newerThan: "1.0",
                buildVersion: "2"
            )
        )
    }

    @Test func sameShortVersionUsesBuildNumberAsTiebreaker() {
        #expect(
            InstalledAppVersion.isRemoteVersion(
                "1.0",
                buildVersion: "10",
                newerThan: "1.0",
                buildVersion: "2"
            )
        )
    }

    @Test func olderShortVersionIsRejectedEvenWithHigherBuildNumber() {
        #expect(
            !InstalledAppVersion.isRemoteVersion(
                "0.9.9",
                buildVersion: "999",
                newerThan: "1.0",
                buildVersion: "1"
            )
        )
    }

    @Test func dottedVersionsCompareNumerically() {
        #expect(InstalledAppVersion.compareVersionString("1.0.10", to: "1.0.2") == .orderedDescending)
        #expect(InstalledAppVersion.compareVersionString("1.0", to: "1.0.0") == .orderedSame)
        #expect(InstalledAppVersion.compareVersionString("1.2", to: "1.10") == .orderedAscending)
    }
}
