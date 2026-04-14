import Foundation
import Testing
@testable import Echo

@Suite("MSSQLBatchSplitter")
struct MSSQLBatchSplitterTests {

    // MARK: - No GO

    @Test func noGO_returnsSingleBatch() {
        let result = MSSQLBatchSplitter.split("SELECT 1")
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1")
        #expect(result.batches[0].repeatCount == 1)
        #expect(result.batches[0].startLine == 0)
    }

    @Test func emptyInput_returnsNoBatches() {
        let result = MSSQLBatchSplitter.split("")
        #expect(result.batches.isEmpty)
    }

    @Test func whitespaceOnly_returnsNoBatches() {
        let result = MSSQLBatchSplitter.split("   \n   \n   ")
        #expect(result.batches.isEmpty)
    }

    // MARK: - Basic GO Split

    @Test func basicGOSplit() {
        let sql = "SELECT 1\nGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0].text == "SELECT 1")
        #expect(result.batches[1].text == "SELECT 2")
    }

    @Test func multipleGOs() {
        let sql = "SELECT 1\nGO\nSELECT 2\nGO\nSELECT 3"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 3)
        #expect(result.batches[0].text == "SELECT 1")
        #expect(result.batches[1].text == "SELECT 2")
        #expect(result.batches[2].text == "SELECT 3")
    }

    @Test func goAtEndOfScript() {
        let sql = "SELECT 1\nGO"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1")
    }

    @Test func goAtStartOfScript() {
        let sql = "GO\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1")
    }

    @Test func consecutiveGOs() {
        let sql = "SELECT 1\nGO\nGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0].text == "SELECT 1")
        #expect(result.batches[1].text == "SELECT 2")
    }

    // MARK: - Case Insensitivity

    @Test func goCaseInsensitive() {
        let cases = ["go", "Go", "GO", "gO"]
        for goVariant in cases {
            let sql = "SELECT 1\n\(goVariant)\nSELECT 2"
            let result = MSSQLBatchSplitter.split(sql)
            #expect(result.batches.count == 2, "Failed for GO variant: \(goVariant)")
        }
    }

    // MARK: - GO with Count

    @Test func goWithCount() {
        let sql = "INSERT INTO t VALUES (1)\nGO 5"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 5)
    }

    @Test func goWithCountZero_treatedAsOne() {
        let sql = "SELECT 1\nGO 0"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 1)
    }

    @Test func goWithLargeCount() {
        let sql = "SELECT 1\nGO 1000"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 1000)
    }

    // MARK: - GO with Comments

    @Test func goWithTrailingComment() {
        let sql = "SELECT 1\nGO -- end of batch"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1")
    }

    @Test func goWithCountAndComment() {
        let sql = "SELECT 1\nGO 3 -- repeat three times"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 3)
    }

    // MARK: - GO Semicolon (Invalid)

    @Test func goSemicolon_notASeparator() {
        let sql = "SELECT 1\nGO;\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        // GO; is not a valid separator — entire text is one batch
        #expect(result.batches.count == 1)
    }

    // MARK: - GO Inside Strings

    @Test func goInsideSingleQuoteString() {
        let sql = "SELECT 'GO' AS word"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 'GO' AS word")
    }

    @Test func goOnOwnLineInsideMultiLineString() {
        let sql = "SELECT '\nGO\n' AS word"
        let result = MSSQLBatchSplitter.split(sql)
        // GO is inside a string spanning multiple lines — should NOT split
        #expect(result.batches.count == 1)
    }

    @Test func escapedQuoteDoesNotEndString() {
        let sql = "SELECT 'it''s'\nGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0].text == "SELECT 'it''s'")
    }

    // MARK: - GO Inside Comments

    @Test func goInsideLineComment() {
        let sql = "-- GO\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "-- GO\nSELECT 1")
    }

    @Test func goInsideBlockComment() {
        let sql = "/* \nGO\n */\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    @Test func goInsideNestedBlockComment() {
        let sql = "/* outer /* inner\nGO\n*/ still comment */\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    // MARK: - GO Inside Bracket Identifier

    @Test func goInsideBracketIdentifier() {
        let sql = "SELECT [GO] FROM t"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    @Test func goOnOwnLineInsideMultiLineBracketIdentifier() {
        let sql = "SELECT [\nGO\n] FROM t"
        let result = MSSQLBatchSplitter.split(sql)
        // This is unusual but bracket identifiers can span lines in T-SQL
        #expect(result.batches.count == 1)
    }

    // MARK: - GO Not at Line Start

    @Test func goNotAtLineStart_notASeparator() {
        let sql = "SELECT 1 GO"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1 GO")
    }

    @Test func gotoKeyword_notASeparator() {
        let sql = "GOTO label1"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    // MARK: - GO with Leading Whitespace

    @Test func goWithLeadingWhitespace() {
        let sql = "SELECT 1\n  GO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    @Test func goWithLeadingTab() {
        let sql = "SELECT 1\n\tGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    // MARK: - Start Line Tracking

    @Test func startLineTracking() {
        let sql = "SELECT 1\nGO\nSELECT 2\nFROM t\nGO\nSELECT 3"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 3)
        #expect(result.batches[0].startLine == 0)
        #expect(result.batches[1].startLine == 2)
        #expect(result.batches[2].startLine == 5)
    }

    // MARK: - GO with Non-Numeric Text (Invalid)

    @Test func goFollowedByText_notASeparator() {
        let sql = "SELECT 1\nGO abc\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        // GO abc is not a valid GO — entire text is one batch
        #expect(result.batches.count == 1)
    }

    @Test func goFollowedByIdentifier_notASeparator() {
        let sql = "SELECT 1\nGO SELECT\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    // MARK: - GO with Tab Spacing

    @Test func goWithTabBeforeCount() {
        let sql = "SELECT 1\nGO\t5"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 5)
    }

    // MARK: - GO with Trailing Whitespace Only

    @Test func goWithTrailingWhitespaceOnly() {
        let sql = "SELECT 1\nGO   \nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    @Test func goWithTrailingTabOnly() {
        let sql = "SELECT 1\nGO\t\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    // MARK: - GO with N-Prefixed Strings

    @Test func goInsideNPrefixedUnicodeString() {
        let sql = "SELECT N'GO' AS word"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    @Test func goOnOwnLineInsideMultiLineNString() {
        let sql = "SELECT N'\nGO\n' AS word"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    // MARK: - GO Inside Double-Quoted Identifier

    @Test func goInsideDoubleQuotedIdentifier() {
        // When QUOTED_IDENTIFIER is ON, double quotes delimit identifiers
        // Our splitter doesn't track double-quote state (SSMS doesn't either for GO),
        // but GO inside "GO" on its own line is extremely rare in practice.
        // This test documents the behavior.
        let sql = "SELECT \"GO\" FROM t"
        let result = MSSQLBatchSplitter.split(sql)
        // "GO" on same line as SELECT — not at line start, so not a separator
        #expect(result.batches.count == 1)
    }

    // MARK: - GO with Count and Semicolon

    @Test func goWithCountAndSemicolon_notASeparator() {
        let sql = "SELECT 1\nGO 5;\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        // GO 5; has trailing semicolon after count — not valid
        #expect(result.batches.count == 1)
    }

    // MARK: - GO at EOF Without Trailing Newline

    @Test func goAtEOFWithoutNewline() {
        let sql = "SELECT 1\nGO"  // no trailing \n
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text == "SELECT 1")
    }

    @Test func goWithCountAtEOFWithoutNewline() {
        let sql = "SELECT 1\nGO 3"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 3)
    }

    // MARK: - All Empty Batches

    @Test func allEmptyBatches_noOutput() {
        let sql = "GO\nGO\nGO"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.isEmpty)
    }

    @Test func emptyBatchesBetweenContent() {
        let sql = "SELECT 1\nGO\n\nGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
        #expect(result.batches[0].text == "SELECT 1")
        #expect(result.batches[1].text == "SELECT 2")
    }

    // MARK: - Block Comment Ending on Same Line as GO

    @Test func blockCommentEndingThenGOOnSameLine() {
        // */ GO on same line — GO is not at line start (there's */ before it)
        let sql = "/* comment */ GO\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        // GO is not at line start (preceded by block comment end) — not a separator
        #expect(result.batches.count == 1)
        #expect(result.batches[0].text.contains("SELECT 1"))
    }

    @Test func blockCommentEndAndGOOnSameLine() {
        let sql = "/* comment */ GO\nSELECT 1"
        let result = MSSQLBatchSplitter.split(sql)
        // GO is not at line start (preceded by block comment end) — not a separator
        #expect(result.batches.count == 1)
    }

    // MARK: - Very Large Batch Count

    @Test func goWithVeryLargeCount() {
        let sql = "SELECT 1\nGO 10000"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
        #expect(result.batches[0].repeatCount == 10000)
    }

    // MARK: - GO with Mixed Whitespace

    @Test func goWithMixedLeadingWhitespace() {
        let sql = "SELECT 1\n \t  GO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    // MARK: - GO with Windows Line Endings

    @Test func goWithWindowsLineEndings() {
        let sql = "SELECT 1\r\nGO\r\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    // MARK: - String Not Closed Before GO

    @Test func unclosedStringSuppressesGO() {
        // If a string is opened but not closed, GO on the next line should not split
        let sql = "SELECT 'unclosed string\nGO\nstill in string'"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 1)
    }

    // MARK: - Escaped Bracket in Identifier

    @Test func escapedBracketInsideIdentifier() {
        let sql = "SELECT [col]]name] FROM t\nGO\nSELECT 2"
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 2)
    }

    // MARK: - CREATE PROCEDURE with GO (Typical SSMS Pattern)

    @Test func createProcedureTypicalPattern() {
        let sql = """
        USE [mydb]
        GO
        CREATE PROCEDURE [dbo].[MyProc]
        AS
        BEGIN
            SELECT 1
            SELECT 2
        END
        GO
        EXEC [dbo].[MyProc]
        GO
        """
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 3)
        #expect(result.batches[0].text == "USE [mydb]")
        #expect(result.batches[1].text.hasPrefix("CREATE PROCEDURE"))
        #expect(result.batches[2].text == "EXEC [dbo].[MyProc]")
    }

    // MARK: - Complex Real-World Script

    @Test func complexScript() {
        let sql = """
        USE [master]
        GO
        CREATE TABLE [dbo].[Test] (
            [ID] INT IDENTITY(1,1) PRIMARY KEY,
            [Name] NVARCHAR(50) NOT NULL,
            [Description] NVARCHAR(MAX) -- GO is not a separator here
        )
        GO
        INSERT INTO [dbo].[Test] ([Name], [Description])
        VALUES ('Item 1', 'Contains ''GO'' in the value')
        GO 3
        SELECT * FROM [dbo].[Test]
        GO
        /* This is a comment block
        GO
        that spans multiple lines */
        DROP TABLE [dbo].[Test]
        GO
        """
        let result = MSSQLBatchSplitter.split(sql)
        #expect(result.batches.count == 5)
        #expect(result.batches[0].text == "USE [master]")
        #expect(result.batches[1].text.hasPrefix("CREATE TABLE"))
        #expect(result.batches[2].repeatCount == 3)
        #expect(result.batches[3].text == "SELECT * FROM [dbo].[Test]")
        #expect(result.batches[4].text.contains("DROP TABLE"))
    }
}
