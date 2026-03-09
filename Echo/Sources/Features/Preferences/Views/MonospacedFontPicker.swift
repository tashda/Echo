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

    private var filteredFamilies: [String] {
        if searchText.isEmpty {
            return monospacedFamilies
        }
        return monospacedFamilies.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Font Family") {
                Picker("", selection: $selectedFamily) {
                    ForEach(monospacedFamilies, id: \.self) { family in
                        Text(displayName(for: family)).tag(family)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 140, idealWidth: 180, maxWidth: 220, alignment: .trailing)
            }

            fontPreview
        }
    }

    private var fontPreview: some View {
        let previewFont: Font = {
            if let nsFont = NSFont(name: selectedFamily, size: fontSize) {
                return Font(nsFont)
            }
            return .system(size: fontSize, design: .monospaced)
        }()
        return Text("SELECT * FROM users WHERE id = 42;")
            .font(previewFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private func displayName(for family: String) -> String {
        if SQLEditorTheme.isSystemFontIdentifier(family) {
            return "System Monospaced"
        }
        return family
    }
}
