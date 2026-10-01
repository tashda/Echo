import Testing
@testable import Echo

@MainActor
@Suite("Result column forms")
struct ResultColumnFormsTests {
    private typealias Coordinator = QueryResultsTableView.Coordinator

    @Test func sameFormsKeepTheFractionWidths() {
        let forms: [ResultCellValueForm] = [.plain, .decimal]
        #expect(!Coordinator.formsChanged(forms, from: forms, fractionColumns: 2))
    }

    @Test func differentFormsStartAgain() {
        #expect(Coordinator.formsChanged([.plain, .decimal], from: [.plain, .plain], fractionColumns: 2))
    }

    @Test func missingFractionWidthsStartAgain() {
        let forms: [ResultCellValueForm] = [.plain, .decimal]
        #expect(Coordinator.formsChanged(forms, from: forms, fractionColumns: 0))
    }
}
