import SwiftUI
import SQLServerKit

/// Chooses one of the server's extended events (a server has a couple of thousand): a button showing the choice, and under it a
/// popover with a search field over a list grouped by package. A dropdown with every event took 1.8 s to open and held
/// 300 MB; this list only builds the rows in view.
struct ExtendedEventPicker: View {
    let events: [SQLServerXEEvent]
    @Binding var selection: String

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Text(selection.isEmpty ? "Select event\u{2026}" : selection)
                    .foregroundStyle(selection.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: SpacingTokens.xs)
                Image(systemName: "chevron.up.chevron.down")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Event")
        .accessibilityValue(selection.isEmpty ? "None" : selection)
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            ExtendedEventPickerList(events: events) { event in
                selection = event.id
                isShowing = false
            }
        }
    }
}

private struct ExtendedEventPickerList: View {
    let events: [SQLServerXEEvent]
    let onChoose: (SQLServerXEEvent) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        let search = ExtendedEventSearch(events: events, query: query)
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            TextField("", text: $query, prompt: Text("Search events"))
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit { if let first = search.first { onChoose(first) } }

            if search.groups.isEmpty {
                Text("No event matches \u{201C}\(query)\u{201D}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxl, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                        ForEach(search.groups) { group in
                            Section {
                                ForEach(group.events) { event in
                                    EventRow(event: event) { onChoose(event) }
                                }
                            } header: {
                                Text(group.packageName)
                                    .font(TypographyTokens.detail.weight(.semibold))
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, SpacingTokens.xxs)
                                    .background(.background)
                            }
                        }
                    }
                }
                .frame(height: ExtendedEventPickerMetrics.listHeight)
                Text("\(search.count) events")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .floatingSurfaceContent(.medium)
        .onAppear { searchFocused = true }
    }

    private struct EventRow: View {
        let event: SQLServerXEEvent
        let onChoose: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: onChoose) {
                Text(event.eventName)
                    .font(TypographyTokens.standard)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, SpacingTokens.xxs)
                    .padding(.horizontal, SpacingTokens.xs)
                    .background(isHovering ? ColorTokens.Surface.hover : .clear, in: .rect(cornerRadius: SpacingTokens.xxs))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(event.description ?? event.id)
            .onHover { isHovering = $0 }
        }
    }
}

private enum ExtendedEventPickerMetrics {
    static let listHeight: CGFloat = 280
}
