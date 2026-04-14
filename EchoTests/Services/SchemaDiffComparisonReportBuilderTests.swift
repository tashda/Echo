import Testing
@testable import Echo

@Suite("SchemaDiffComparisonReportBuilder")
struct SchemaDiffComparisonReportBuilderTests {
    @Test func markdownReportIncludesSummaryAndRows() {
        let report = SchemaDiffComparisonReportBuilder.build(
            sourceSchema: "sakila",
            targetSchema: "sakila_next",
            diffs: sampleDiffs,
            format: .markdown
        )

        #expect(report.contains("# Schema Comparison Report"))
        #expect(report.contains("Added: 1"))
        #expect(report.contains("| Added | table | actor | No | Yes |"))
    }

    @Test func htmlReportEscapesUnsafeNames() {
        let report = SchemaDiffComparisonReportBuilder.build(
            sourceSchema: "a",
            targetSchema: "b",
            diffs: [
                SchemaDiffItem(
                    objectType: "view",
                    objectName: "<danger>",
                    status: .modified,
                    sourceDDL: "select 1",
                    targetDDL: "select 2"
                ),
            ],
            format: .html
        )

        #expect(report.contains("&lt;danger&gt;"))
        #expect(!report.contains("<danger>"))
    }

    @Test func textReportReflectsPresenceOfSourceAndTargetDDL() {
        let report = SchemaDiffComparisonReportBuilder.build(
            sourceSchema: "a",
            targetSchema: "b",
            diffs: sampleDiffs,
            format: .text
        )

        #expect(report.contains("source: missing | target: present"))
        #expect(report.contains("source: present | target: missing"))
    }

    private var sampleDiffs: [SchemaDiffItem] {
        [
            SchemaDiffItem(objectType: "table", objectName: "actor", status: .added, sourceDDL: nil, targetDDL: "create table actor"),
            SchemaDiffItem(objectType: "view", objectName: "actor_view", status: .removed, sourceDDL: "create view actor_view", targetDDL: nil),
        ]
    }
}
