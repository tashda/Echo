import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Duotone tree icons")
struct SidebarDuotoneSymbolsTests {
    @Test func symbolsWithAFillVariantGetIt() {
        #expect(SidebarDuotoneSymbols.fillName(for: "cylinder") == "cylinder.fill")
        #expect(SidebarDuotoneSymbols.fillName(for: "tablecells") == "tablecells.fill")
    }

    @Test func symbolsWithoutOneDrawTheOutlineOnly() {
        #expect(SidebarDuotoneSymbols.fillName(for: "function") == nil)
        #expect(SidebarDuotoneSymbols.fillName(for: "cylinder.fill") == nil)
        #expect(SidebarDuotoneSymbols.fillName(for: "no.such.symbol.here") == nil)
    }
}
