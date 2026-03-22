import XCTest

@MainActor
class EchoUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
}
