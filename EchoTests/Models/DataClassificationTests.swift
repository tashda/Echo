import Testing
@testable import Echo

struct DataClassificationTests {

    // MARK: - SensitivityRank

    @Test func rankComparison() {
        #expect(SensitivityRank.low < .medium)
        #expect(SensitivityRank.medium < .high)
        #expect(SensitivityRank.high < .critical)
        #expect(SensitivityRank.notDefined < .low)
    }

    @Test func rankDisplayNames() {
        #expect(SensitivityRank.notDefined.displayName == "Not Defined")
        #expect(SensitivityRank.low.displayName == "Low")
        #expect(SensitivityRank.medium.displayName == "Medium")
        #expect(SensitivityRank.high.displayName == "High")
        #expect(SensitivityRank.critical.displayName == "Critical")
    }

    // MARK: - ColumnSensitivity

    @Test func columnSensitivitySummaryWithBothLabelAndInfoType() {
        let sensitivity = ColumnSensitivity(
            label: SensitivityLabel(name: "Confidential", id: "1"),
            informationType: InformationType(name: "SSN", id: "2"),
            rank: .high
        )
        #expect(sensitivity.summary == "Confidential / SSN")
        #expect(sensitivity.effectiveRank == .high)
    }

    @Test func columnSensitivitySummaryWithLabelOnly() {
        let sensitivity = ColumnSensitivity(
            label: SensitivityLabel(name: "Public", id: "1"),
            informationType: nil,
            rank: .low
        )
        #expect(sensitivity.summary == "Public")
    }

    @Test func columnSensitivitySummaryWithInfoTypeOnly() {
        let sensitivity = ColumnSensitivity(
            label: nil,
            informationType: InformationType(name: "Email", id: "2"),
            rank: nil
        )
        #expect(sensitivity.summary == "Email")
        #expect(sensitivity.effectiveRank == .notDefined)
    }

    @Test func columnSensitivitySummaryWithNoLabelOrInfoType() {
        let sensitivity = ColumnSensitivity(label: nil, informationType: nil, rank: .medium)
        #expect(sensitivity.summary == "Classified")
    }

    // MARK: - DataClassification

    @Test func classificationLookupByColumnIndex() {
        let classification = DataClassification(
            labels: [SensitivityLabel(name: "Confidential", id: "1")],
            informationTypes: [InformationType(name: "SSN", id: "2")],
            columns: [
                0: ColumnSensitivity(
                    label: SensitivityLabel(name: "Confidential", id: "1"),
                    informationType: InformationType(name: "SSN", id: "2"),
                    rank: .critical
                ),
                2: ColumnSensitivity(
                    label: SensitivityLabel(name: "Confidential", id: "1"),
                    informationType: nil,
                    rank: .medium
                )
            ],
            overallRank: .critical
        )

        #expect(classification.hasClassifiedColumns)
        #expect(classification.classification(forColumnAt: 0)?.effectiveRank == .critical)
        #expect(classification.classification(forColumnAt: 1) == nil)
        #expect(classification.classification(forColumnAt: 2)?.effectiveRank == .medium)
    }

    @Test func emptyClassificationHasNoColumns() {
        let classification = DataClassification(
            labels: [],
            informationTypes: [],
            columns: [:],
            overallRank: nil
        )
        #expect(!classification.hasClassifiedColumns)
        #expect(classification.classification(forColumnAt: 0) == nil)
    }

    // MARK: - QueryResultSet Integration

    @Test func queryResultSetCarriesClassification() {
        let classification = DataClassification(
            labels: [],
            informationTypes: [],
            columns: [0: ColumnSensitivity(label: nil, informationType: nil, rank: .low)],
            overallRank: .low
        )
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "secret", dataType: "nvarchar")],
            rows: [["value"]],
            totalRowCount: 1,
            dataClassification: classification
        )
        #expect(result.dataClassification?.hasClassifiedColumns == true)
        #expect(result.dataClassification?.classification(forColumnAt: 0)?.effectiveRank == .low)
    }

    @Test func queryResultSetDefaultsToNilClassification() {
        let result = QueryResultSet(
            columns: [ColumnInfo(name: "id", dataType: "int")],
            rows: [["1"]]
        )
        #expect(result.dataClassification == nil)
    }
}
