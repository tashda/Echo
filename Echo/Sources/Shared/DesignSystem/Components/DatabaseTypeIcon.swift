import SwiftUI

struct DatabaseTypeIcon: View {
    let databaseType: DatabaseType
    var tint: Color? = nil
    var isColorful: Bool = true
    var presentation: RasterSymbolPresentation = .standard
    var glyphScale: CGFloat = 1

    @ViewBuilder
    var body: some View {
#if os(macOS)
        if let nativeImage = nativeImage {
            Image(nsImage: nativeImage)
                .renderingMode(databaseType.usesTemplateIcon ? .template : .original)
                .foregroundStyle(foregroundTint)
                .grayscale(isColorful || databaseType.usesTemplateIcon ? 0 : 1)
                .accessibilityHidden(true)
        } else {
            fallbackBody
        }
#else
        fallbackBody
#endif
    }

    @ViewBuilder
    private var fallbackBody: some View {
        SymbolLikeAssetImage(
            assetName: databaseType.iconName,
            isTemplate: databaseType.usesTemplateIcon,
            tint: tint,
            isColorful: isColorful,
            presentation: presentation,
            glyphScale: glyphScale
        )
    }

    private var foregroundTint: Color {
        if databaseType.usesTemplateIcon {
            return isColorful ? (tint ?? Color.primary) : ColorTokens.Sidebar.symbol
        }
        return .primary
    }

#if os(macOS)
    private var nativeImage: NSImage? {
        switch presentation {
        case .menu:
            databaseType.menuIconImage()
        case .formControl:
            databaseType.formControlIconImage()
        case .standard, .landingRecent, .sidebar:
            nil
        }
    }
#endif
}
