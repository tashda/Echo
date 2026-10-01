import SwiftUI
import AppKit

struct MonospacedFontPicker: View {
    @Binding var selectedFamily: String
    var fontSize: Double

    @State private var searchText = ""

    private var monospacedFamilies: [String] {
        let allFamilies = NSFontManager.shared.availableFontFamilies
        return allFamilies.filter { family in
            guard let font = NSFont(name: family, size: 13) else { return false }
            let descriptor = font.fontDescriptor
            if let traits = descriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any],
               let symbolic = traits[.symbolic] as? UInt32 {
                let symbolicTraits = NSFontDescriptor.SymbolicTraits(rawValue: symbolic)
                return symbolicTraits.contains(.monoSpace)
            }
            return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
        }.sorted()
    }

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
        monospacedFamilies.contains(value)
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
                    ForEach(bundledFamilies, id: \.self) { family in
                        Text(displayName(for: family)).tag(family)
                    }
                }
                Section("Installed on This Mac") {
                    ForEach(installedFamilies, id: \.self) { family in
                        Text(displayName(for: family)).tag(family)
                    }
                }
                if !isKnown(selectedFamily) {
                    Text(displayName(for: SQLEditorTheme.defaultFontFamily)).tag(selectedFamily)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 140, idealWidth: 180, maxWidth: 220, alignment: .trailing)
        }
    }

    private func displayName(for family: String) -> String {
        if SQLEditorTheme.isSystemFontIdentifier(family) {
            return "System Monospaced"
        }
        return SQLEditorTheme.bundledFontDisplayNames[family] ?? family
    }
}
