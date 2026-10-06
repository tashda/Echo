import Foundation
import Testing
@testable import Echo

struct MonospacedFontCatalogTests {
    @Test func findsTheMonospacedFamiliesOnceAndKeepsThem() async {
        let first = await MonospacedFontCatalog.load()

        #expect(first.isEmpty == false)
        #expect(first == first.sorted())
        #expect(Set(first).count == first.count)
        #expect(MonospacedFontCatalog.cachedFamilies == first)

        let second = await MonospacedFontCatalog.load()
        #expect(second == first)
    }

    @Test func everyFamilyIsMonospaced() async {
        let families = await MonospacedFontCatalog.load()
        let known = families.filter { ["Menlo", "Monaco", "Courier New"].contains($0) }

        #expect(known.isEmpty == false, "the Mac's own monospaced fonts are listed")
        #expect(families.contains("Helvetica") == false)
    }
}
