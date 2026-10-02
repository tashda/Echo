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

    // MARK: Slot

    @Test func largerNamesNeedMoreRoom() {
        let small = ServerHeaderSlot.requiredHeight(for: .small)
        let large = ServerHeaderSlot.requiredHeight(for: .large)
        #expect(large > small)
        #expect(ServerHeaderSlot.extraHeight(for: .large, originalSlot: 1000) == 0)
        #expect(ServerHeaderSlot.extraHeight(for: .medium, originalSlot: 49) > 0)
    }
}

@Suite("Server header settings (round 53)")
struct ServerHeaderSettingsTests {
    @Test func defaultsAreTheChosenLook() {
        let look = ServerHeaderLook()
        #expect(look.typeface == .system)
        #expect(look.nameSize == .medium)
        #expect(look.nameSize.points == 22)
        #expect(look.eyebrow == .section)
        #expect(look.edge == .hairline)
        #expect(look.textColor == .white)
        #expect(GlobalSettings().serverHeaderStyle == .titleBanner)
    }

    @Test func sizesAreEighteenTwentyTwoTwentySix() {
        #expect(ServerHeaderNameSize.allCases.map(\.points) == [18, 22, 26])
    }

    @Test func edgesOfferNoRoundedCorners() {
        #expect(ServerHeaderEdge.allCases.map(\.rawValue) == ["sharp", "hairline", "softFade", "frostedFade"])
    }

    @Test func lookRoundTrips() throws {
        var look = ServerHeaderLook()
        look.typeface = .serif
        look.nameSize = .large
        look.eyebrow = .engineAndSection
        look.edge = .frostedFade
        look.textColor = .automatic
        let decoded = try JSONDecoder().decode(ServerHeaderLook.self, from: JSONEncoder().encode(look))
        #expect(decoded == look)
    }

    @Test func lookKeepsDefaultsForMissingOrUnknownValues() throws {
        let decoded = try JSONDecoder().decode(ServerHeaderLook.self, from: Data(#"{"typeface":"wingdings","edge":"sharp"}"#.utf8))
        #expect(decoded.typeface == .system)
        #expect(decoded.edge == .sharp)
        #expect(decoded.nameSize == .medium)
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
