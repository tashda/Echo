import AppKit
import CoreText
import SwiftUI

/// Round 28: the editor fonts Echo bundles (`Echo/Resources/Fonts`), registered for Echo Labs
/// straight from the repo, so the specimens draw the code exactly as Echo does.
@MainActor
enum LabQEFonts {
    private static var isRegistered = false
    private static var metricsCache: [String: LabQEFontMetrics] = [:]

    static func registerOnce() {
        guard !isRegistered else { return }
        isRegistered = true
        // EchoLab/Sources/EchoLab/Ongoing/QueryEditor/LabQEFonts.swift: the repo is six folders up.
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { repo.deleteLastPathComponent() }
        let folder = repo.appending(path: "Echo/Resources/Fonts")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where ["ttf", "otf"].contains(file.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }

    /// The font at a size, with ligatures (and the contextual alternates that draw them) on or off.
    static func nsFont(_ family: LabQEFont, size: CGFloat, ligatures: Bool) -> NSFont {
        registerOnce()
        let base: NSFont = switch family {
        case .sfMono: .monospacedSystemFont(ofSize: size, weight: .regular)
        default: NSFontManager.shared.font(withFamily: family.familyName, traits: [], weight: 5, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        guard !ligatures else { return base }
        let off: [[NSFontDescriptor.FeatureKey: Int]] = [
            [.typeIdentifier: kLigaturesType, .selectorIdentifier: kCommonLigaturesOffSelector],
            [.typeIdentifier: kContextualAlternatesType, .selectorIdentifier: kContextualAlternatesOffSelector],
        ]
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: off])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    /// The width of one column and the height NSLayoutManager gives a line of this font.
    static func metrics(_ family: LabQEFont, size: CGFloat) -> LabQEFontMetrics {
        let key = "\(family.rawValue)-\(size)"
        if let cached = metricsCache[key] { return cached }
        let font = nsFont(family, size: size, ligatures: false)
        let advance = ("0" as NSString).size(withAttributes: [.font: font]).width
        let made = LabQEFontMetrics(advance: advance, naturalLineHeight: NSLayoutManager().defaultLineHeight(for: font))
        metricsCache[key] = made
        return made
    }
}

struct LabQEFontMetrics {
    let advance: CGFloat
    let naturalLineHeight: CGFloat
}

/// The fonts the owner can pick from: Echo's bundled families and the system's SF Mono.
enum LabQEFont: String, CaseIterable {
    case jetBrains = "JetBrains Mono (today)"
    case sfMono = "SF Mono"
    case geist = "Geist Mono"
    case commit = "Commit Mono"
    case cascadia = "Cascadia Code"
    case intelOne = "Intel One Mono"
    case martian = "Martian Mono"
    case fragment = "Fragment Mono"
    case atkinson = "Atkinson Hyperlegible Mono"
    case googleSans = "Google Sans Code"
    case monaspaceNeon = "Monaspace Neon"
    case monaspaceArgon = "Monaspace Argon"

    var familyName: String {
        switch self {
        case .jetBrains: "JetBrains Mono"
        case .sfMono: "SF Mono"
        case .commit: "CommitMono"
        case .monaspaceNeon: "Monaspace Neon Var"
        case .monaspaceArgon: "Monaspace Argon Var"
        default: rawValue
        }
    }

    var summary: String {
        switch self {
        case .jetBrains: "Echo's default: tall lower case, open shapes, ligatures. Made for code by JetBrains."
        case .sfMono: "The system's monospaced font, as in Xcode and Terminal; the gutter's digits are already SF."
        case .geist: "Vercel's: geometric and calm, close to SF Mono with a little more character."
        case .commit: "Neutral and quiet, tuned for long reading."
        case .cascadia: "Microsoft's, from Windows Terminal; rounder, with ligatures."
        case .intelOne: "Designed for low vision: very clear 0/O and 1/l/I."
        case .martian: "Wide and square; reads well large, takes room."
        case .fragment: "Helvetica-like grotesque in a monospace."
        case .atkinson: "From the Braille Institute: every character made unmistakable."
        case .googleSans: "Google's code face, friendly and round."
        case .monaspaceNeon: "GitHub's neo-grotesque; texture healing evens the spacing."
        case .monaspaceArgon: "GitHub's humanist variant: softer than Neon."
        }
    }
}
