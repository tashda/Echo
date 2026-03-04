import SwiftUI

/// Shared UI components and helpers for table structure editor sheets.
enum TableStructureSheetHelpers {
    
    @ViewBuilder
    static func labeledRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 0)
            content()
        }
        .frame(maxWidth: .infinity)
    }
    
    static func cardRowBackground(isNew: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(isNew ? 0.35 : 0.2), lineWidth: 0.8)
            )
    }
    
    @ViewBuilder
    static func bubbleLabel(
        _ text: String,
        systemImage: String? = nil,
        tint: Color = Color(nsColor: .unemphasizedSelectedTextBackgroundColor),
        foreground: Color = .secondary,
        subtitle: String? = nil
    ) -> some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .padding(.top, subtitle == nil ? 0 : 1)
            }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(foreground.opacity(0.8))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, subtitle == nil ? 4 : 6)
        .background(
            Capsule()
                .fill(tint)
        )
        .overlay(
            Capsule()
                .stroke(Color(nsColor: .separatorColor).opacity(0.18))
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
