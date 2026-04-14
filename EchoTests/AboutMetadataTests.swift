import Foundation
import Testing
@testable import Echo

struct AboutMetadataTests {
    @Test func quickLinksIncludeHomepageAndDrivers() {
        let titles = Set(AboutMetadata.quickLinks.map(\.title))

        #expect(titles.contains("Echo Homepage"))
        #expect(titles.contains("postgres-wire"))
        #expect(titles.contains("sqlserver-nio"))
        #expect(titles.contains("mysql-wire"))
    }

    @Test func dependenciesExposeRepositoryURLs() {
        #expect(AboutMetadata.dependencies.isEmpty == false)
        #expect(AboutMetadata.dependencies.allSatisfy { $0.repositoryURL.scheme == "https" })
        #expect(AboutMetadata.dependencies.contains { $0.name == "Sparkle" && $0.licenseURL != nil })
    }
}
