import SwiftUI

enum RasterSymbolPresentation: Sendable {
    case standard
    case menu
    case formControl
    case landingRecent
    case sidebar

    var canvasWidth: CGFloat {
        switch self {
        case .standard, .menu, .formControl:
            return LayoutTokens.Icon.standardCanvas
        case .landingRecent:
            return LayoutTokens.Icon.landingRecentCanvas
        case .sidebar:
            return LayoutTokens.Icon.sidebarCanvasWidth
        }
    }

    var canvasHeight: CGFloat {
        switch self {
        case .standard:
            return LayoutTokens.Icon.standardCanvas
        case .menu:
            return LayoutTokens.Icon.menuCanvas
        case .formControl:
            return LayoutTokens.Icon.formControlCanvas
        case .landingRecent:
            return LayoutTokens.Icon.landingRecentCanvas
        case .sidebar:
            return LayoutTokens.Icon.sidebarCanvasHeight
        }
    }

    var glyphSize: CGFloat {
        switch self {
        case .standard:
            return LayoutTokens.Icon.standardGlyph
        case .menu:
            return LayoutTokens.Icon.menuGlyph
        case .formControl:
            return LayoutTokens.Icon.formControlGlyph
        case .landingRecent:
            return LayoutTokens.Icon.landingRecentGlyph
        case .sidebar:
            return LayoutTokens.Icon.sidebarGlyph
        }
    }
}

struct SymbolLikeAssetImage: View {
    let assetName: String
    let isTemplate: Bool
    var tint: Color? = nil
    var isColorful: Bool = true
    var presentation: RasterSymbolPresentation = .standard
    var glyphScale: CGFloat = 1

    @ViewBuilder
    var body: some View {
        ZStack {
            if isTemplate {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isColorful ? (tint ?? Color.primary) : ColorTokens.Sidebar.symbol)
                    .frame(width: presentation.glyphSize * glyphScale, height: presentation.glyphSize * glyphScale)
            } else {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .grayscale(isColorful ? 0 : 1)
                    .frame(width: presentation.glyphSize * glyphScale, height: presentation.glyphSize * glyphScale)
            }
        }
        .frame(width: presentation.canvasWidth, height: presentation.canvasHeight)
        .accessibilityHidden(true)
    }
}
