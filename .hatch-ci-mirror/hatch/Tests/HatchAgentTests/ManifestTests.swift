import XCTest
@testable import HatchAgent

final class ManifestTests: XCTestCase {
    func testRoundTrip() throws {
        let m = Fixture.manifest()
        XCTAssertEqual(try ProposalManifest.parse(json: try m.jsonString()), m)
    }

    func testEmptyObjectDecodesAndGateSaysWhatIsMissing() throws {
        let m = try ProposalManifest.parse(json: "{}")
        XCTAssertEqual(m.revision, 1)
        XCTAssertTrue(codes(ProposalValidator.validate(m)).contains("echo-today.missing"))
    }

    func testEchoLabsWordExhibitsIsAccepted() throws {
        let m = try ProposalManifest.parse(json: #"{"exhibits":[{"id":"today","isEchoToday":true,"designWidth":340,"designHeight":400}]}"#)
        XCTAssertEqual(m.specimens.first?.id, "today")
    }

    func testDefaultKeyIsDefault() throws {
        let m = try ProposalManifest.parse(json: #"{"controls":[{"id":"s","choices":[{"id":"a","name":"A"}],"default":"a"}]}"#)
        XCTAssertEqual(m.controls[0].defaultChoice, "a")
        XCTAssertTrue(try m.jsonString().contains("\"default\""))
    }

    func testErrorsNameTheBadPlace() {
        XCTAssertThrowsError(try ProposalManifest.parse(json: #"{"specimens":[{"title":"No id"}]}"#)) { e in
            XCTAssertTrue("\(e)".contains("specimens[0]") && "\(e)".contains("id"), "\(e)")
        }
        XCTAssertThrowsError(try ProposalManifest.parse(json: #"{"revision":"two"}"#)) { e in XCTAssertTrue("\(e)".contains("revision"), "\(e)") }
        XCTAssertThrowsError(try ProposalManifest.parse(json: "not json"))
    }

    func testSketchManifestRules() throws {
        let ok = try SketchManifest.parse(json: #"{"summary":"s","variants":[{"id":"a","title":"A","html":"a.html"},{"id":"b","title":"B","html":"b.html"}]}"#)
        XCTAssertEqual(ok.validate(), [])
        let one = SketchManifest(variants: [.init(id: "a", title: "A", html: "a.html")])
        XCTAssertEqual(codes(one.validate()), ["sketch.variant-count"])
        let escape = SketchManifest(variants: [.init(id: "a", title: "A", html: "../x.html"), .init(id: "a", title: "", html: "b.html")])
        XCTAssertTrue(Set(codes(escape.validate())).isSuperset(of: ["sketch.html-path", "sketch.id-duplicate", "sketch.title-missing"]))
    }
}
