import SwiftUI
import AppKit
import Synchronization

struct MonospacedFontPicker: View {
    @Binding var selectedFamily: String
    var fontSize: Double

    @State private var searchText = ""
    /// The monospaced families, once found (`MonospacedFontCatalog`); empty until then.
    @State private var monospacedFamilies = MonospacedFontCatalog.cachedFamilies ?? []

    /// The fonts Echo ships (design board, 2026-09-30), in the order the picker lists them.
    private var bundledFamilies: [String] {
        let available = Set(monospacedFamilies)
        return SQLEditorTheme.bundledFontFamilies.filter { available.contains($0) }
    }

    private var installedFamilies: [String] {
        let bundled = Set(SQLEditorTheme.bundledFontFamilies)
        return monospacedFamilies.filter { !bundled.contains($0) }
    }

    /// Saved values may be a family ("Geist Mono") or a PostScript name ("JetBrainsMono-Regular").
    private func isKnown(_ value: String) -> Bool {
        // Until the list is found, nothing is called unknown: no stand-in row flashes in the menu.
        monospacedFamilies.isEmpty || monospacedFamilies.contains(value)
    }

    private var filteredFamilies: [String] {
        if searchText.isEmpty {
            return monospacedFamilies
        }
        return monospacedFamilies.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        PropertyRow(title: "Font Family") {
            Picker("", selection: $selectedFamily) {
                Section("Echo") {
                    // Round 28.1: SF Mono, the system's monospaced font, is the default.
                    Text(displayName(for: SQLEditorTheme.systemFontIdentifier)).tag(SQLEditorTheme.systemFontIdentifier)
                    ForEach(bundledFamilies, id: \.self) { family in
                        Text(displayName(for: family)).tag(family)
                    }
                }
                Section("Installed on This Mac") {
                    ForEach(installedFamilies, id: \.self) { family in
                        Text(displayName(for: family)).tag(family)
                    }
                }
                if !isKnown(selectedFamily), !SQLEditorTheme.isSystemFontIdentifier(selectedFamily) {
                    Text(displayName(for: SQLEditorTheme.defaultFontFamily)).tag(selectedFamily)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 140, idealWidth: 180, maxWidth: 220, alignment: .trailing)
        }
        .task {
            guard monospacedFamilies.isEmpty else { return }
            monospacedFamilies = await MonospacedFontCatalog.load()
        }
    }

    private func displayName(for family: String) -> String {
        if SQLEditorTheme.isSystemFontIdentifier(family) {
            return "SF Mono"
        }
        return SQLEditorTheme.bundledFontDisplayNames[family] ?? family
    }
}

/// Every installed monospaced font family. Asking each of the Mac's fonts for its traits takes
/// most of a second, so it is done once, off the main thread, and kept.
nonisolated enum MonospacedFontCatalog {
    private static let found = Mutex<[String]?>(nil)

    static var cachedFamilies: [String]? { found.withLock { $0 } }

    @concurrent static func load() async -> [String] {
        if let cached = cachedFamilies { return cached }
        let families = NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 13) else { return false }
            let descriptor = font.fontDescriptor
            if let traits = descriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any],
               let symbolic = traits[.symbolic] as? UInt32 {
                return NSFontDescriptor.SymbolicTraits(rawValue: symbolic).contains(.monoSpace)
            }
            return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
        }.sorted()
        found.withLock { $0 = families }
        return families
    }
}
