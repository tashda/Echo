import Testing
import Foundation
@testable import Echo

/// Verifies that required entitlements are present in both the production
/// and debug entitlements files. This prevents accidental removal of
/// capabilities (e.g., Sign In with Apple) from breaking features at runtime.
@Suite("Entitlement Verification")
struct EntitlementVerificationTests {

    // MARK: - Helpers

    /// Locates the project root by walking up from the test bundle.
    private func projectRoot() throws -> URL {
        // In CI/Xcode, the test bundle sits inside DerivedData. Walk up until
        // we find Echo.xcodeproj, which marks the project root.
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            let marker = url.appendingPathComponent("Echo.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                return url
            }
        }
        throw EntitlementTestError.projectRootNotFound
    }

    private func loadEntitlements(at path: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: path)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data, format: nil
        ) as? [String: Any] else {
            throw EntitlementTestError.invalidPlist
        }
        return plist
    }

    private enum EntitlementTestError: Error {
        case projectRootNotFound
        case invalidPlist
    }

    // MARK: - Production Entitlements

    @Test func productionEntitlementsContainSignInWithApple() throws {
        let root = try projectRoot()
        let path = root.appendingPathComponent("Echo/Echo.entitlements")
        let entitlements = try loadEntitlements(at: path)

        let key = "com.apple.developer.applesignin"
        let value = try #require(entitlements[key] as? [String],
                                  "Missing entitlement: \(key) in Echo.entitlements")
        #expect(value.contains("Default"),
                "Sign In with Apple entitlement must include 'Default' scope")
    }

    @Test func productionEntitlementsContainNetworkClient() throws {
        let root = try projectRoot()
        let path = root.appendingPathComponent("Echo/Echo.entitlements")
        let entitlements = try loadEntitlements(at: path)

        let key = "com.apple.security.network.client"
        let value = try #require(entitlements[key] as? Bool,
                                  "Missing entitlement: \(key) in Echo.entitlements")
        #expect(value == true)
    }

    // MARK: - Debug Entitlements

    @Test func debugEntitlementsContainSignInWithApple() throws {
        let root = try projectRoot()
        let path = root.appendingPathComponent("Echo/EchoDebug.entitlements")
        let entitlements = try loadEntitlements(at: path)

        let key = "com.apple.developer.applesignin"
        let value = try #require(entitlements[key] as? [String],
                                  "Missing entitlement: \(key) in EchoDebug.entitlements")
        #expect(value.contains("Default"),
                "Sign In with Apple entitlement must include 'Default' scope")
    }

    @Test func debugEntitlementsContainGetTaskAllow() throws {
        let root = try projectRoot()
        let path = root.appendingPathComponent("Echo/EchoDebug.entitlements")
        let entitlements = try loadEntitlements(at: path)

        let key = "com.apple.security.get-task-allow"
        let value = try #require(entitlements[key] as? Bool,
                                  "Missing entitlement: \(key) in EchoDebug.entitlements")
        #expect(value == true)
    }
}
