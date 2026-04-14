import Testing
@testable import Echo

struct QueryStatementClassifierTests {
    @Test
    func alterTableIsMessageOnly() {
        #expect(
            QueryStatementClassifier.isLikelyMessageOnlyStatement(
                "ALTER TABLE dbo.people ADD nickname text NULL;",
                databaseType: .microsoftSQL
            )
        )
    }

    @Test
    func selectRemainsResultSetStatement() {
        #expect(
            !QueryStatementClassifier.isLikelyMessageOnlyStatement(
                "SELECT * FROM dbo.people;",
                databaseType: .microsoftSQL
            )
        )
    }

    @Test
    func returningOverridesDmlClassification() {
        #expect(
            !QueryStatementClassifier.isLikelyMessageOnlyStatement(
                "INSERT INTO people(name) VALUES ('Ana') RETURNING id;",
                databaseType: .postgresql
            )
        )
    }
}
