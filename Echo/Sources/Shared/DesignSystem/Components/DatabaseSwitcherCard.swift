import SwiftUI
import AppKit

/// The database switcher that grows out of the footer's server · database chip
/// (Design/05-components.md › Results card, round 9 DB1): a floating card with a filter field at
/// the top, the databases, and the chip's own label at the bottom where the chip was. Type to
/// narrow the list, use the arrow keys and Return, or click. Esc or a click outside closes it.
///
/// The glass comes from the footer, so the chip's glass can morph into this card's.
struct DatabaseSwitcherCard: View {
    let databases: [String]
    let currentDatabase: String?
    let chipLabel: String
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @State private var filter = ""
    @State private var highlighted: String?
    @State private var cardFrame: CGRect = .zero
    @State private var eventMonitor: Any?
    @FocusState private var isFilterFocused: Bool

    private var matches: [String] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return databases }
        return databases.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            filterField
            list
            Text(chipLabel)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.Footer.chipHeight, alignment: .leading)
        }
        .padding(LayoutTokens.FloatingSurface.padding)
        .frame(width: LayoutTokens.FloatingSurface.smallWidth, alignment: .leading)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrame = $0 }
        .onAppear {
            highlighted = currentDatabase
            installEventMonitor()
            // After the card is on screen, or the editor keeps the keyboard.
            Task { @MainActor in isFilterFocused = true }
        }
        .onDisappear(perform: removeEventMonitor)
        .onChange(of: filter) { _, _ in
            if let highlighted, matches.contains(highlighted) { return }
            highlighted = matches.first
        }
    }

    private var filterField: some View {
        TextField("Filter Databases", text: $filter, prompt: Text("Filter \(databases.count) databases"))
            .textFieldStyle(.plain)
            .font(TypographyTokens.caption2)
            .labelsHidden()
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.FloatingSurface.rowHeight)
            .background(
                ColorTokens.Sidebar.hoverFill,
                in: RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
            )
            .focused($isFilterFocused)
            .onSubmit(selectHighlighted)
            .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
            .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
    }

    @ViewBuilder
    private var list: some View {
        if matches.isEmpty {
            Text("No matching databases")
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.xs)
                .frame(height: LayoutTokens.FloatingSurface.rowHeight, alignment: .leading)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SpacingTokens.none) {
                        ForEach(matches, id: \.self) { database in
                            row(database)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(
                    CGFloat(matches.count) * LayoutTokens.FloatingSurface.rowHeight,
                    LayoutTokens.Footer.switcherListMaxHeight
                ))
                .onAppear { proxy.scrollTo(currentDatabase, anchor: .center) }
                .onChange(of: highlighted) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func row(_ database: String) -> some View {
        let isCurrent = database.caseInsensitiveCompare(currentDatabase ?? "") == .orderedSame
        return Button { onSelect(database) } label: {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "cylinder")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.accent)
                Text(database)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: SpacingTokens.xs)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.accent)
                }
            }
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.FloatingSurface.rowHeight)
            .background(
                database == highlighted ? ColorTokens.Sidebar.selectedFill : .clear,
                in: RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { highlighted = database } }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: - Keyboard

    private func moveHighlight(by step: Int) {
        guard !matches.isEmpty else { return }
        let index = highlighted.flatMap { matches.firstIndex(of: $0) } ?? (step > 0 ? -1 : matches.count)
        highlighted = matches[min(max(index + step, 0), matches.count - 1)]
    }

    private func selectHighlighted() {
        if let highlighted, matches.contains(highlighted) {
            onSelect(highlighted)
        } else if let first = matches.first {
            onSelect(first)
        }
    }

    // MARK: - Click outside and Esc

    /// Closes on Esc wherever the keyboard is, and on any click outside the card in this window
    /// or elsewhere in the app; that click still goes where it was aimed.
    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { event in
            let isEscape = event.type == .keyDown && event.keyCode == Self.escapeKeyCode
            let isKey = event.type == .keyDown
            let location = event.locationInWindow
            let contentHeight = event.window?.contentView?.bounds.height
            let swallow = MainActor.assumeIsolated {
                if isEscape {
                    onDismiss()
                    return true
                }
                if !isKey && !isInsideCard(location, contentHeight: contentHeight) {
                    onDismiss()
                }
                return false
            }
            return swallow ? nil : event
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }

    private static let escapeKeyCode: UInt16 = 53

    /// SwiftUI's global frame is measured from the top of the window's content; AppKit's event
    /// location from the bottom.
    private func isInsideCard(_ location: CGPoint, contentHeight: CGFloat?) -> Bool {
        guard let contentHeight else { return false }
        return cardFrame.contains(CGPoint(x: location.x, y: contentHeight - location.y))
    }
}
