import CoreGraphics
import Foundation
import Testing
@testable import Echo

/// Round 57: the dock row's morph into a pill is a function of the scroll offset and the card's
/// place (HB3, MP0, PS0), and each card remembers where its sections were left (CK1).
@Suite("Explorer dock morph")
struct ExplorerDockMorphTests {
    /// A card at 100 with a 43pt banner, a 37pt dock slot and a bottom at 700.
    private let morph = ExplorerDockMorph(cardTop: 100, nameHeight: 43, dockHeight: 37, cardBottom: 700)

    @Test func atRestTheDockIsTheWholeSlot() {
        #expect(morph.progress(offset: 0) == 0)
        #expect(morph.progress(offset: 100) == 0)
        #expect(morph.height(progress: 0) == 37)
        #expect(morph.width(cardWidth: 280, progress: 0) == 280)
        #expect(morph.cornerRadius(progress: 0) == 0)
        // Where the scroll view has it: nothing to move.
        #expect(morph.pinOffset(naturalTop: 143 - 100) == 0)
    }

    @Test func theMorphFollowsTheScrollOneToOne() {
        let distance = 43 - ExplorerDockMorph.pillTop
        #expect(morph.progress(offset: 100 + distance / 2) == 0.5)
        #expect(morph.progress(offset: 100 + distance) == 1)
        #expect(morph.progress(offset: 400) == 1)
        // Back again: the same offset is the same progress.
        #expect(morph.progress(offset: 100 + distance / 2) == morph.progress(offset: 100 + distance / 2))
    }

    @Test func theSameProgressFromTheViewsGeometry() {
        for offset in stride(from: CGFloat(60), through: 300, by: 7) {
            #expect(abs(morph.progress(offset: offset) - morph.progress(naturalTop: morph.dockTop - offset)) < 1e-9)
        }
    }

    @Test func thePillEndsAtItsSizeAndIsACapsule() {
        #expect(morph.height(progress: 1) == ExplorerDockMorph.pillHeight)
        #expect(morph.width(cardWidth: 280, progress: 1) == ExplorerDockMorph.pillWidth)
        #expect(morph.cornerRadius(progress: 1) == ExplorerDockMorph.pillHeight / 2)
        // A card narrower than the pill is never widened.
        #expect(morph.width(cardWidth: 150, progress: 1) == 150)
    }

    @Test func theDockRowScrollsWithTheContentUntilItReachesThePillsPlace() {
        // Above the pill's place: the row is where the scroll view has it.
        #expect(morph.top(offset: 100) == 43)
        #expect(morph.top(offset: 120) == 23)
        // Then it is held 8pt from the top.
        #expect(morph.top(offset: 150) == ExplorerDockMorph.pillTop)
        #expect(morph.top(offset: 500) == ExplorerDockMorph.pillTop)
    }

    @Test func theNextCardPushesThePillUpAndOut() {
        // The card ends at 700: the pill's bottom plus 8pt never passes it.
        let offset: CGFloat = 700 - 38 - 8 - 8 + 20
        let top = morph.top(offset: offset)
        #expect(top == 700 - offset - 30 - 8)
        #expect(top < ExplorerDockMorph.pillTop)
        #expect(morph.bottom(offset: offset) + ExplorerDockMorph.pillTop == 700 - offset)
        // Far enough, it is out of the view altogether.
        #expect(morph.bottom(offset: 700) < 0)
    }

    @Test func pinningMovesTheRowByTheDifferenceFromItsNaturalPlace() {
        for offset in stride(from: CGFloat(0), through: 760, by: 13) {
            let natural = morph.dockTop - offset
            #expect(abs(natural + morph.pinOffset(naturalTop: natural) - morph.top(offset: offset)) < 1e-9)
        }
    }

    // MARK: - Where each section was left

    private let server = UUID()

    @Test func aFirstVisitGoesToTheCardsTopOnlyWhenScrolledIntoIt() {
        let places = ExplorerDockPlaces()
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 400, maxOffset: 900) == 100)
        // The card's top is still below the top of the view: the view stays.
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 40, maxOffset: 900) == nil)
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 100, maxOffset: 900) == nil)
    }

    @Test func aSectionReturnsToWhereItWasLeft() {
        var places = ExplorerDockPlaces()
        places.save(250, connectionID: server, section: "tables")
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 120, maxOffset: 900) == 350)
        // Another section has its own place.
        #expect(places.place(connectionID: server, section: "views") == nil)
    }

    @Test func aRememberedPlaceIsClampedToWhatTheContentAllows() {
        var places = ExplorerDockPlaces()
        places.save(800, connectionID: server, section: "tables")
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 120, maxOffset: 500) == 500)
    }

    @Test func aPlaceOfZeroMeansTheCardsTop() {
        var places = ExplorerDockPlaces()
        places.save(0, connectionID: server, section: "tables")
        places.save(-30, connectionID: server, section: "views")
        #expect(places.place(connectionID: server, section: "views") == 0)
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 300, maxOffset: 900) == 100)
    }

    @Test func noMoveWhenTheViewIsAlreadyThere() {
        var places = ExplorerDockPlaces()
        places.save(250, connectionID: server, section: "tables")
        #expect(places.target(connectionID: server, section: "tables", cardTop: 100, offset: 350.2, maxOffset: 900) == nil)
    }

    @Test func aDisconnectedServerIsForgotten() {
        var places = ExplorerDockPlaces()
        let other = UUID()
        places.save(250, connectionID: server, section: "tables")
        places.save(90, connectionID: other, section: "tables")
        places.drop(keeping: [other])
        #expect(places.place(connectionID: server, section: "tables") == nil)
        #expect(places.place(connectionID: other, section: "tables") == 90)
    }

    // MARK: - Held room when a section is shorter

    @Test func aShorterSectionKeepsTheTotalHeightUntilTheViewScrollsUp() {
        // The section's content went from 1000 to 700 high with the view 400 into a 400pt view.
        #expect(ExplorerTreeHold.spacerHeight(offset: 600, viewport: 400, contentHeight: 700, previousTotal: 1_000) == 300)
        // The smooth scroll up to the card's top gives the room back as it goes.
        #expect(ExplorerTreeHold.spacerHeight(offset: 450, viewport: 400, contentHeight: 700, previousTotal: 1_000) == 150)
        #expect(ExplorerTreeHold.spacerHeight(offset: 300, viewport: 400, contentHeight: 700, previousTotal: 1_000) == 0)
        // Another card arriving below makes the rows tall enough: nothing is held.
        #expect(ExplorerTreeHold.spacerHeight(offset: 600, viewport: 400, contentHeight: 1_100, previousTotal: 1_000) == 0)
    }
}
