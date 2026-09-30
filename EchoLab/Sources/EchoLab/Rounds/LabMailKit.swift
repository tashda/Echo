import SwiftUI

/// The pieces shared by the Inbox and the Rounds page, which both read like a mailbox: a list
/// on the left and a reading pane on the right.

extension LabStatus {
    /// The colour that means this status everywhere in the lab.
    var tint: Color {
        switch self {
        case .newFeedback: ColorTokens.Status.warning
        case .judging: ColorTokens.accent
        case .accepted: ColorTokens.Status.success
        case .inEcho: .purple
        case .decided: ColorTokens.Text.tertiary
        }
    }

    var symbol: String {
        switch self {
        case .newFeedback: "exclamationmark.bubble.fill"
        case .judging: "hand.tap.fill"
        case .accepted: "checkmark.circle.fill"
        case .inEcho: "shippingbox.fill"
        case .decided: "checkmark.seal.fill"
        }
    }
}

/// A status as a tinted pill with its icon.
struct LabStatusChip: View {
    let status: LabStatus
    var body: some View {
        Label(status.rawValue, systemImage: status.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8).frame(height: 20)
            .background(status.tint.opacity(0.14), in: Capsule())
    }
}

/// A small rounded tag, for an area or a count.
struct LabTag: View {
    let text: String
    var symbol: String?
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9)) }
            Text(text)
        }
        .font(.system(size: 11)).foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, 7).frame(height: 19)
        .background(Color.primary.opacity(0.07), in: Capsule())
    }
}

/// The search field and filter that sit above a mailbox list.
struct LabMailHeader<Filter: View>: View {
    let title: String
    let subtitle: String
    @Binding var search: String
    @ViewBuilder var filter: Filter

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(TypographyTokens.title2.weight(.bold))
                Text(subtitle).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("", text: $search, prompt: Text("Search"))
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.horizontal, 8).frame(height: 28).labField(cornerRadius: 8)
            filter
        }
        .padding(SpacingTokens.sm)
    }
}

/// A card in a reading pane: a small title and content.
struct LabReadingCard<Content: View>: View {
    let title: String
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabColumnTitle(text: title, symbol: symbol)
            content
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .labCard(cornerRadius: 14)
    }
}

/// Shown in a reading pane when nothing is selected.
struct LabMailEmpty: View {
    let title: String
    let symbol: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
