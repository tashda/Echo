import Foundation
import Testing
@testable import Echo

@Suite("Server header title banner (round 53)")
struct ServerHeaderTitleTests {
    // MARK: Line above the name

    @Test func openCardNamesTheSectionInCapitals() {
        let text = ServerHeaderEyebrow.text(line: .section, engine: "SQL SERVER", section: "Databases", isOpen: true)
        #expect(text == "DATABASES")
    }

    @Test func collapsedCardNeverShowsTheSection() {
        for line in [ServerHeaderEyebrowLine.section, .engineAndSection] {
            let text = ServerHeaderEyebrow.text(line: line, engine: "POSTGRESQL", section: "Security", isOpen: false)
            #expect(text == "POSTGRESQL")
        }
    }

    @Test func engineLineIsTheSameOpenAndClosed() {
        #expect(ServerHeaderEyebrow.text(line: .engine, engine: "MYSQL", section: "Tables", isOpen: true) == "MYSQL")
        #expect(ServerHeaderEyebrow.text(line: .engine, engine: "MYSQL", section: "Tables", isOpen: false) == "MYSQL")
    }

    @Test func engineAndSectionJoinsThemWhenOpen() {
        let text = ServerHeaderEyebrow.text(line: .engineAndSection, engine: "SQL SERVER", section: "Security", isOpen: true)
        #expect(text == "SQL SERVER · SECURITY")
    }

    @Test func openCardWithoutADockFallsBackToTheEngine() {
        #expect(ServerHeaderEyebrow.text(line: .section, engine: "SQLITE", section: nil, isOpen: true) == "SQLITE")
    }

    @Test func noLineIsNil() {
        #expect(ServerHeaderEyebrow.text(line: .none, engine: "MYSQL", section: "Tables", isOpen: true) == nil)
    }

    @Test func engineNamesHaveNoVersion() {
        #expect(ServerHeaderEyebrow.engineName(for: .microsoftSQL) == "SQL SERVER")
        #expect(ServerHeaderEyebrow.engineName(for: .postgresql) == "POSTGRESQL")
        #expect(ServerHeaderEyebrow.engineName(for: .mysql) == "MYSQL")
    }

    // MARK: Automatic text colour

    @Test func lightColoursGetDarkType() {
        let amber = ServerColorPalette.components(forStored: "E5A100", isDark: false)!
        #expect(ServerHeaderContrast.prefersDarkType(red: amber.red, green: amber.green, blue: amber.blue))
        let amberDark = ServerColorPalette.components(forStored: "E5A100", isDark: true)!
        #expect(ServerHeaderContrast.prefersDarkType(red: amberDark.red, green: amberDark.green, blue: amberDark.blue))
    }

    @Test func deepColoursKeepWhiteType() {
        for hex in ["2563EB", "C62F3B", "1D2F5C", "5A9CDE"] {
            let rgb = ServerColorPalette.components(forStored: hex, isDark: false)!
            #expect(!ServerHeaderContrast.prefersDarkType(red: rgb.red, green: rgb.green, blue: rgb.blue), "\(hex)")
        }
    }

    @Test func luminanceUsesRec709Weights() {
        #expect(ServerHeaderContrast.luminance(red: 1, green: 1, blue: 1) == 1)
        #expect(ServerHeaderContrast.luminance(red: 0, green: 1, blue: 0) == 0.7152)
    }
}

@Suite("Server header settings (round 53)")
struct ServerHeaderSettingsTests {
    @Test func defaultsAreTheChosenLook() {
        let look = ServerHeaderLook()
        #expect(look.typeface == .system)
        #expect(look.nameSize == .standard)
        #expect(look.nameSize.points == 18)
        #expect(look.eyebrow == .section)
        #expect(look.spacing == .tight)
        #expect(look.edge == .hairline)
        #expect(look.textColor == .white)
        #expect(GlobalSettings().serverHeaderStyle == .titleBanner)
    }

    @Test func sizesRunFromTwelveToTwentySix() {
        #expect(ServerHeaderNameSize.allCases.map(\.points) == [12, 14, 16, 18, 22, 26])
    }

    @Test func savedSizesFromBeforeRound58KeepTheirPoints() throws {
        func decoded(_ raw: String) throws -> ServerHeaderNameSize {
            try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"spacing":"tight","nameSize":"\#(raw)","eyebrow":"engine"}"#.utf8)).nameSize
        }
        #expect(try decoded("small").points == 18)
        #expect(try decoded("medium").points == 22)
        #expect(try decoded("large").points == 26)
    }

    @Test func theOldDefaultMovesToTheNewDefaultOnce() throws {
        let old = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"nameSize":"medium","eyebrow":"section"}"#.utf8))
        #expect(old.nameSize == .standard && old.eyebrow == .section && old.spacing == .tight)
        // An explicit other choice is kept.
        let large = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"nameSize":"large","eyebrow":"section"}"#.utf8))
        #expect(large.nameSize == .extraLarge)
        let engine = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"nameSize":"medium","eyebrow":"engine"}"#.utf8))
        #expect(engine.nameSize == .large && engine.eyebrow == .engine)
        // Saved after the move (spacing is there): 22pt and the section are a choice now.
        let chosen = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"nameSize":"pt22","eyebrow":"section","spacing":"standard"}"#.utf8))
        #expect(chosen.nameSize == .large && chosen.spacing == .standard)
    }

    @Test func edgesOfferNoRoundedCorners() {
        #expect(ServerHeaderEdge.allCases.map(\.rawValue) == ["sharp", "hairline", "softFade", "frostedFade"])
    }

    @Test func lookRoundTrips() throws {
        var look = ServerHeaderLook()
        look.typeface = .serif
        look.nameSize = .extraLarge
        look.eyebrow = .sectionAtRight
        look.spacing = .standard
        look.edge = .frostedFade
        look.textColor = .automatic
        let decoded = try JSONDecoder().decode(ServerHeaderLook.self, from: JSONEncoder().encode(look))
        #expect(decoded == look)
    }

    @Test func lookKeepsDefaultsForMissingOrUnknownValues() throws {
        let decoded = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"typeface":"wingdings","edge":"sharp"}"#.utf8))
        #expect(decoded.typeface == .system)
        #expect(decoded.edge == .sharp)
        #expect(decoded.nameSize == .standard)
    }

    @Test func savedWashBecomesTheNewDefaultOnce() {
        #expect(GlobalSettings.decodedServerHeaderStyle(.wash, hasLook: false) == .titleBanner)
        #expect(GlobalSettings.decodedServerHeaderStyle(.wash, hasLook: true) == .wash)
    }

    @Test func otherSavedStylesAndMissingOnesDecode() {
        for style in [ServerHeaderStyle.plain, .bar, .plate, .banner] {
            #expect(GlobalSettings.decodedServerHeaderStyle(style, hasLook: false) == style)
        }
        #expect(GlobalSettings.decodedServerHeaderStyle(nil, hasLook: false) == .titleBanner)
    }

    @Test func existingStylesStillDecodeFromTheirOldNames() throws {
        for name in ["wash", "plain", "bar", "plate", "banner"] {
            let style = try JSONDecoder().decode(ServerHeaderStyle.self, from: Data("\"\(name)\"".utf8))
            #expect(style.rawValue == name)
        }
    }
}

@Suite("Server colour palette (round 50, PC3)")
struct ServerColorPaletteTests {
    @Test func thirtyColoursWithDistinctNamesAndHexes() {
        #expect(ServerColorPalette.all.count == 30)
        #expect(Set(ServerColorPalette.all.map(\.name)).count == 30)
        #expect(Set(ServerColorPalette.all.map(\.lightHex)).count == 30)
    }

    @Test func aPaletteColourShowsItsDarkTwinInDark() throws {
        let crimson = try #require(ServerColorPalette.color(forStored: "C62F3B"))
        #expect(crimson.name == "Crimson")
        #expect(crimson.dark == 0xFF5A67)
        let light = try #require(ServerColorPalette.components(forStored: "C62F3B", isDark: false))
        let dark = try #require(ServerColorPalette.components(forStored: "C62F3B", isDark: true))
        #expect(abs(light.red - Double(0xC6) / 255) < 0.0001)
        #expect(abs(dark.red - 1.0) < 0.0001)
        #expect(abs(dark.green - Double(0x5A) / 255) < 0.0001)
    }

    @Test func lookupIgnoresCaseAndHash() {
        #expect(ServerColorPalette.color(forStored: "#c62f3b")?.name == "Crimson")
        #expect(ServerColorPalette.name(forStored: "#2563eb") == "Azure")
    }

    @Test func savedColoursOutsideThePaletteKeepDecoding() throws {
        // The five colours the sheet offered before, and a colour from the colour well.
        for hex in ["5A9CDE", "6EAE72", "E8943A", "9B72CF", "D4687A", "#123456"] {
            #expect(ServerColorPalette.color(forStored: hex) == nil)
            let light = try #require(ServerColorPalette.components(forStored: hex, isDark: false))
            let dark = try #require(ServerColorPalette.components(forStored: hex, isDark: true))
            #expect(light.red == dark.red && light.green == dark.green && light.blue == dark.blue)
        }
        #expect(ServerColorPalette.name(forStored: "5A9CDE") == "Blue")
        #expect(ServerColorPalette.name(forStored: "#123456") == nil)
    }

    @Test func emptyAndDefaultAreNotColours() {
        #expect(ServerColorPalette.components(forStored: "", isDark: false) == nil)
        #expect(ServerColorPalette.components(forStored: "default", isDark: false) == nil)
    }

    @Test func shortHexExpands() throws {
        let rgb = try #require(ServerColorPalette.components(forStored: "F00", isDark: false))
        #expect(rgb.red == 1 && rgb.green == 0 && rgb.blue == 0)
    }

    @Test func defaultColourIsInThePalette() {
        #expect(ServerColorPalette.all.contains(ServerColorPalette.defaultColor))
        #expect(ServerColorPalette.defaultColor.name == "Azure")
    }

    @Test func everyDarkTwinIsLighterOrEqualToItsLightColour() {
        for entry in ServerColorPalette.all {
            let light = ServerColorPalette.components(forStored: entry.lightHex, isDark: false)!
            let dark = ServerColorPalette.components(forStored: entry.lightHex, isDark: true)!
            let lightLuma = ServerHeaderContrast.luminance(red: light.red, green: light.green, blue: light.blue)
            let darkLuma = ServerHeaderContrast.luminance(red: dark.red, green: dark.green, blue: dark.blue)
            #expect(darkLuma >= lightLuma - 0.001, "\(entry.name)")
        }
    }
}

@Suite("Server header metrics")
struct ServerHeaderMetricsTests {
    private static let sizes = ServerHeaderNameSize.allCases
    private static let lines = ServerHeaderEyebrowLine.allCases
    private static let spacings = ServerHeaderSpacing.allCases

    private static func everyLook(_ body: (ServerHeaderMetrics, ServerHeaderNameSize, ServerHeaderEyebrowLine, ServerHeaderSpacing) -> Void) {
        for size in sizes { for line in lines { for spacing in spacings {
            body(ServerHeaderMetrics(nameSize: size, eyebrow: line, spacing: spacing), size, line, spacing)
        } } }
    }

    @Test func theNumbersAreTheAcceptedOnes() {
        #expect(ServerHeaderMetrics.eyebrowLineHeight == 12)
        #expect(ServerHeaderMetrics.lineGap == 3)
        #expect(ServerHeaderSpacing.tight.topInset == 6)
        #expect(ServerHeaderSpacing.standard.topInset == 10)
        #expect(ServerHeaderNameSize.allCases.map { ServerHeaderMetrics(nameSize: $0, eyebrow: .none).nameLineHeight } == [14, 17, 19, 22, 26, 31])
    }

    @Test func nothingAboveTheNameIsTheNameAlone() {
        for size in Self.sizes {
            for spacing in Self.spacings {
                let metrics = ServerHeaderMetrics(nameSize: size, eyebrow: .none, spacing: spacing)
                #expect(metrics.eyebrowBlockHeight == 0)
                #expect(metrics.linesHeight == metrics.nameLineHeight)
                #expect(metrics.headerHeight == spacing.topInset + metrics.nameLineHeight + spacing.dockGap)
            }
        }
    }

    @Test func everyCombinationIsTheSumOfItsParts() {
        Self.everyLook { metrics, size, line, spacing in
            let above = line.isOverName ? ServerHeaderMetrics.eyebrowLineHeight + ServerHeaderMetrics.lineGap : 0
            let name = (size.points * 1.2).rounded()
            let row = line == .sectionAtRight ? max(name, ServerHeaderMetrics.eyebrowLineHeight) : name
            #expect(metrics.headerHeight == spacing.topInset + above + row + spacing.dockGap, "\(size) \(line) \(spacing)")
        }
    }

    @Test func theLineOverTheNameAddsItsHeightAndGapAndTheRightHandSectionAddsNothing() {
        for size in Self.sizes {
            for spacing in Self.spacings {
                let none = ServerHeaderMetrics(nameSize: size, eyebrow: .none, spacing: spacing).headerHeight
                for line in Self.lines where line.isOverName {
                    #expect(ServerHeaderMetrics(nameSize: size, eyebrow: line, spacing: spacing).headerHeight
                        == none + ServerHeaderMetrics.eyebrowLineHeight + ServerHeaderMetrics.lineGap)
                }
                #expect(ServerHeaderMetrics(nameSize: size, eyebrow: .sectionAtRight, spacing: spacing).headerHeight == none)
            }
        }
    }

    @Test func standardAddsEightPoints() {
        for size in Self.sizes {
            for line in Self.lines {
                let tight = ServerHeaderMetrics(nameSize: size, eyebrow: line, spacing: .tight).headerHeight
                #expect(ServerHeaderMetrics(nameSize: size, eyebrow: line, spacing: .standard).headerHeight == tight + 8)
            }
        }
    }

    @Test func largerNamesNeedMoreRoom() {
        for line in Self.lines {
            for spacing in Self.spacings {
                let heights = Self.sizes.map { ServerHeaderMetrics(nameSize: $0, eyebrow: line, spacing: spacing).headerHeight }
                #expect(heights == heights.sorted() && Set(heights).count == heights.count)
            }
        }
    }

    /// The row the layout reserves is exactly the header, for every sidebar size: no gap, no overlap.
    @MainActor @Test func theReservedRowEqualsTheHeader() {
        for density in SidebarDensity.allCases {
            let base = Double(ObjectBrowserOutlineView.baseRowHeight(for: density))
            let slot = base + Double(ObjectBrowserNode.Row.serverHeaderExtraHeight)
            Self.everyLook { metrics, _, _, _ in
                #expect(slot + metrics.extraHeight(overSlot: slot) == metrics.headerHeight)
            }
        }
    }

    /// What the layout reserves for the server row (`serverHeaderHeight`) is the header, and the
    /// banner paints the header plus the dock's slot, so the lines never meet the dock.
    @MainActor @Test func theTreeReservesTheHeadersHeight() {
        for density in SidebarDensity.allCases {
            Self.everyLook { _, size, line, spacing in
                var settings = GlobalSettings()
                settings.sidebarDensity = density
                settings.serverHeaderStyle = .titleBanner
                settings.serverHeaderLook.nameSize = size
                settings.serverHeaderLook.eyebrow = line
                settings.serverHeaderLook.spacing = spacing
                let expected = ServerHeaderMetrics(nameSize: size, eyebrow: line, spacing: spacing).headerHeight
                #expect(Double(ObjectBrowserNode.Row.serverHeaderHeight(settings: settings)) == expected)
            }
        }
    }

    @Test func linesFitBetweenTheInsets() {
        Self.everyLook { metrics, _, _, _ in
            #expect(metrics.topInset + metrics.linesHeight + metrics.bottomInset == metrics.headerHeight)
            #expect(metrics.nameRowHeight >= metrics.nameLineHeight)
            #expect(metrics.nameRowHeight >= (metrics.eyebrow == .sectionAtRight ? ServerHeaderMetrics.eyebrowLineHeight : 0))
        }
    }

    @Test func theSectionAtTheRightReadsLikeTheSection() {
        #expect(ServerHeaderEyebrow.text(line: .sectionAtRight, engine: "SQL SERVER", section: "Databases", isOpen: true) == "DATABASES")
        #expect(ServerHeaderEyebrow.text(line: .sectionAtRight, engine: "SQL SERVER", section: "Databases", isOpen: false) == "SQL SERVER")
        #expect(ServerHeaderEyebrow.text(line: .none, engine: "SQL SERVER", section: "Databases", isOpen: true) == nil)
    }
}
