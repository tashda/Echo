import SwiftUI

struct IdentityDecoration {
    let label: String
    let symbol: String
    let tooltip: String?
}

struct ConnectionIconCell: View {
    let connection: SavedConnection

    var body: some View {
        iconView
            .frame(width: 16, height: 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconView: some View {
        if let (image, isTemplate) = iconInfo {
            if isTemplate {
                image
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            } else {
                image
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "externaldrive")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.primary)
    }

    private var iconInfo: (Image, Bool)? {
        if let nsImage = NSImage(named: connection.databaseType.iconName) {
            return (Image(nsImage: nsImage), nsImage.isTemplate)
        }
        return nil
    }
}

struct IdentityIconCell: View {
    let identity: SavedIdentity

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.primary)
            .frame(width: 16, height: 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}

struct LeadingTableCell<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 6) {
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

