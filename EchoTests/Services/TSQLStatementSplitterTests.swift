import Foundation
import Testing
@testable import Echo

@Suite("TSQLStatementSplitter")
struct TSQLStatementSplitterTests {

    // MARK: - Single Statement

    @Test func singleStatement() {
        let sql = "SELECT 1"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 1)
        #expect(result[0].text == "SELECT 1")
        #expect(result[0].lineNumber == 1)
    }

    @Test func singleStatementWithSemicolon() {
        let sql = "SELECT 1;"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 1)
        #expect(result[0].text == "SELECT 1;")
    }

    // MARK: - Multiple Statements

    @Test func multipleStatementsSeparatedBySemicolons() {
        let sql = "SELECT 1; SELECT 2; SELECT 3"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 3)
        #expect(result[0].text == "SELECT 1;")
        #expect(result[1].text == "SELECT 2;")
        #expect(result[2].text == "SELECT 3")
    }

    @Test func multipleStatementsOnSeparateLines() {
        let sql = """
        SELECT 1;
        SELECT 2;
        SELECT 3
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 3)
    }

    // MARK: - BEGIN...END Blocks

    @Test func beginEndBlockStaysTogether() {
        let sql = """
        BEGIN
            SELECT 1;
            SELECT 2;
        END
        """
        let result = TSQLStatementSplitter.split(sql)
        // The whole BEGIN...END block should be one statement
        #expect(result.count == 1)
        #expect(result[0].text.contains("BEGIN"))
        #expect(result[0].text.contains("END"))
    }

    @Test func nestedBeginEnd() {
        let sql = """
        BEGIN
            BEGIN
                SELECT 1;
            END;
            SELECT 2;
        END
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 1)
    }

    // MARK: - IF...ELSE with BEGIN...END

    @Test func ifElseWithBeginEnd() {
        let sql = """
        IF 1 = 1
        BEGIN
            SELECT 'yes';
        END
        ELSE
        BEGIN
            SELECT 'no';
        END;
        SELECT 'after'
        """
        let result = TSQLStatementSplitter.split(sql)
        // IF...BEGIN...END ELSE BEGIN...END is one block, then SELECT 'after'
        #expect(result.count == 2)
    }

    // MARK: - GO Separators

    @Test func goSeparatorSplitsBatches() {
        let sql = """
        SELECT 1
        GO
        SELECT 2
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
        #expect(result[0].text == "SELECT 1")
        #expect(result[1].text == "SELECT 2")
    }

    @Test func goCaseInsensitive() {
        let sql = """
        SELECT 1
        go
        SELECT 2
        Go
        SELECT 3
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 3)
    }

    @Test func goNotSplitInsideIdentifier() {
        // "go" in the middle of a line should not split
        let sql = "SELECT category_gopher FROM products"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 1)
    }

    // MARK: - String Literals

    @Test func semicolonsInsideStringNotSplit() {
        let sql = "SELECT 'hello; world'; SELECT 2"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
        #expect(result[0].text.contains("hello; world"))
    }

    @Test func escapedQuoteInString() {
        let sql = "SELECT 'it''s here; yes'; SELECT 2"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
        #expect(result[0].text.contains("it''s here; yes"))
    }

    // MARK: - Comments

    @Test func lineCommentIgnored() {
        let sql = """
        SELECT 1; -- this; is a comment
        SELECT 2
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
    }

    @Test func blockCommentIgnored() {
        let sql = """
        SELECT 1; /* semicolon; inside comment */ SELECT 2
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
    }

    @Test func nestedBlockComments() {
        let sql = "SELECT 1; /* outer /* inner */ still outer */ SELECT 2"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
    }

    // MARK: - Variable Detection

    @Test func detectDeclareVariable() {
        let sql = "DECLARE @count INT"
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        #expect(variables.count == 1)
        #expect(variables[0].name == "@count")
        #expect(variables[0].lineNumber == 1)
    }

    @Test func detectSetVariable() {
        let sql = "SET @count = 42"
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        #expect(variables.count == 1)
        #expect(variables[0].name == "@count")
    }

    @Test func detectMultipleVariables() {
        let sql = """
        DECLARE @a INT, @b VARCHAR(50)
        SET @a = 1
        SET @b = 'hello'
        """
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        #expect(variables.count == 2)
        let names = variables.map(\.name)
        #expect(names.contains("@a"))
        #expect(names.contains("@b"))
    }

    @Test func systemVariablesExcluded() {
        let sql = "SELECT @@ROWCOUNT"
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        #expect(variables.isEmpty)
    }

    // MARK: - Line Numbers

    @Test func lineNumbersAreCorrect() {
        let sql = """
        SELECT 1;
        SELECT 2;
        SELECT 3
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 3)
        #expect(result[0].lineNumber == 1)
        #expect(result[1].lineNumber == 2)
        #expect(result[2].lineNumber == 3)
    }

    // MARK: - Edge Cases

    @Test func emptyInput() {
        let result = TSQLStatementSplitter.split("")
        #expect(result.isEmpty)
    }

    @Test func whitespaceOnly() {
        let result = TSQLStatementSplitter.split("   \n  \n  ")
        #expect(result.isEmpty)
    }

    @Test func consecutiveSemicolons() {
        let sql = "SELECT 1;; SELECT 2"
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 2)
    }

    @Test func declarationAndUsageTogether() {
        let sql = """
        DECLARE @x INT;
        SET @x = 10;
        SELECT @x AS result
        """
        let result = TSQLStatementSplitter.split(sql)
        #expect(result.count == 3)
        let variables = TSQLStatementSplitter.extractVariables(from: sql)
        #expect(variables.count == 1)
        #expect(variables[0].name == "@x")
    }
}
