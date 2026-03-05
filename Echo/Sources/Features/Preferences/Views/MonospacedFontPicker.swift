import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MonospacedFontPicker: View {
    @Binding var selectedFamily: String
    var fontSize: Double

    @State private var searchText = ""

    private var monospacedFamilies: [String] {
        #if os(macOS)
        let allFamilies = NSFontManager.shared.availableFontFamilies
        return allFamilies.filter { family in
            guard let font = NSFont(name: family, size: 13) else { return false }
            let descriptor = font.fontDescriptor
            if let traits = descriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any],
               let symbolic = traits[.symbolic] as? UInt32 {
                let symbolicTraits = NSFontDescriptor.SymbolicTraits(rawValue: symbolic)
                return symbolicTraits.contains(.monoSpace)
            }
            // Fallback: check if the font has a fixed-pitch trait via the font manager
            return NSFontManager.shared.traits(of: font).contains(.fixedPitchFontMask)
        }.sorted()
        #else
        return ["Menlo", "Courier", "SF Mono"]
        #endif
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
            HStack {
                Text("Font Family")
                Spacer()
                Menu {
                    TextField("Search", text: $searchText)

                    Divider()

                    if filteredFamilies.isEmpty {
                        Text("No matching fonts")
                    } else {
                        ForEach(filteredFamilies, id: \.self) { family in
                            Button {
                                selectedFamily = family
                                searchText = ""
                            } label: {
                                HStack {
                                    Text(family)
                                    if family == selectedFamily {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(displayName(for: selectedFamily))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            fontPreview
        }
    }

    private var fontPreview: some View {
        #if os(macOS)
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
        #else
        return Text("SELECT * FROM users WHERE id = 42;")
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        #endif
    }

    private func displayName(for family: String) -> String {
        if SQLEditorTheme.isSystemFontIdentifier(family) {
            return "System Monospaced"
        }
        return family
    }
}
