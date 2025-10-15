import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AutoCompletionListView: View {
    let suggestions: [SQLAutoCompletionSuggestion]
    let selectedID: String?
    let onSelect: (SQLAutoCompletionSuggestion) -> Void
    let detailResetID: UUID

    @Environment(\.colorScheme) private var colorScheme

    @State private var isDetailVisible = false
    @State private var detailWorkItem: DispatchWorkItem?
    @State private var detailUnlocked = false

    private enum Layout {
        static let rowCornerRadius: CGFloat = 12
        static let detailWidth: CGFloat = 240
        static let containerCornerRadius: CGFloat = 18
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 10
        static let containerSpacing: CGFloat = 12
        static let detailRevealDelay: TimeInterval = 1.0
        static let rowHorizontalPadding: CGFloat = 12
        static let rowIconSpacing: CGFloat = 8
        static let rowIconSize: CGFloat = 16
        static let minListWidth: CGFloat = 220
        static let maxColumnListHeight: CGFloat = 180
    }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard let selectedID else { return nil }
        return suggestions.first { $0.id == selectedID }
    }

    private var shouldDisplayDetail: Bool {
        guard let suggestion = selectedSuggestion, isDetailVisible else { return false }
        if let path = suggestion.displayObjectPath, !path.isEmpty { return true }
        if suggestion.kind == .column, let type = suggestion.dataType, !type.isEmpty { return true }
        if suggestion.serverDisplayName != nil { return true }
        return false
    }

#if os(macOS)
    private var listWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let titleWidth = suggestions.map { ( $0.title as NSString).size(withAttributes: attributes).width }.max() ?? 0
        let base = Layout.rowHorizontalPadding * 2 + Layout.rowIconSize + Layout.rowIconSpacing
        return max(Layout.minListWidth, base + titleWidth)
    }
#else
    private var listWidth: CGFloat { Layout.minListWidth }
#endif

    var body: some View {
        content
            .id(detailResetID)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Layout.containerSpacing) {
            listView

            if shouldDisplayDetail, let suggestion = selectedSuggestion {
                AutoCompletionDetailView(suggestion: suggestion)
                    .frame(width: Layout.detailWidth, alignment: .leading)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .id(suggestion.id)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(backgroundMaterial)
        .overlay(borderOverlay)
        .onAppear { scheduleDetailReveal(forceReset: true) }
        .onChange(of: selectedID) { _ in scheduleDetailReveal(forceReset: false) }
        .onChange(of: suggestions) { _ in scheduleDetailReveal(forceReset: false) }
        .onDisappear { cancelDetailReveal() }
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
#if os(macOS)
        Color.clear
#else
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.95))
#endif
    }

    private var borderColor: Color {
#if os(macOS)
        return Color.clear
#else
        return Color.black.opacity(0.1)
#endif
    }

    @ViewBuilder
    private var borderOverlay: some View {
#if os(macOS)
        EmptyView()
#else
        RoundedRectangle(cornerRadius: Layout.containerCornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
#endif
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        suggestionRow(for: suggestion)
                            .id(suggestion.id)
                    }
                }
            }
            .frame(minWidth: listWidth, idealWidth: listWidth)
            .onAppear { scrollToSelection(proxy) }
            .onChange(of: selectedID) { _ in scrollToSelection(proxy) }
        }
    }


    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard let selectedID else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }

    private struct AutoScrollingText: View {
        let text: String
        let font: Font
        let isActive: Bool

        @State private var textWidth: CGFloat = 0

        var body: some View {
            GeometryReader { geometry in
                let available = geometry.size.width
                TimelineView(.animation) { timeline in
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .background(widthReader)
                        .offset(x: offset(for: timeline.date.timeIntervalSinceReferenceDate, available: available))
                }
            }
            .frame(height: 16)
        }

        private var widthReader: some View {
            GeometryReader { geo in
                Color.clear
                    .onAppear { textWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newValue in
                        textWidth = newValue
                    }
            }
        }

        private func offset(for time: TimeInterval, available: CGFloat) -> CGFloat {
            let delta = textWidth - available
            guard isActive, delta > 6 else { return 0 }
            let period = max(Double(delta / 32), 1.6)
            let progress = (sin((time.truncatingRemainder(dividingBy: period)) / period * .pi * 2) + 1) / 2
            return -CGFloat(progress) * delta
        }
    }

    @ViewBuilder
    private func suggestionRow(for suggestion: SQLAutoCompletionSuggestion) -> some View {
        let isSelected = suggestion.id == selectedID

        Button {
            onSelect(suggestion)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: suggestion.kind.iconSystemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor(isSelected: isSelected))
                    .frame(width: 16)

                AutoScrollingText(text: suggestion.title, font: .system(size: 12), isActive: isSelected)
                    .foregroundStyle(titleColor(isSelected: isSelected))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBackground(isSelected: isSelected))
    }

    private func iconColor(isSelected: Bool) -> Color {
#if os(macOS)
        return isSelected ? Color(nsColor: .selectedMenuItemTextColor) : Color.secondary
#else
        return isSelected ? Color.white : Color.secondary
#endif
    }

    private func titleColor(isSelected: Bool) -> Color {
#if os(macOS)
        return isSelected ? Color(nsColor: .selectedMenuItemTextColor) : Color.primary
#else
        return isSelected ? Color.white : Color.primary
#endif
    }

    private func rowBackground(isSelected: Bool) -> some View {
        guard isSelected else {
            return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
                .fill(Color.clear)
        }
#if os(macOS)
        let accent = NSColor.controlAccentColor
        return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
            .fill(Color(nsColor: accent))
#else
        let opacity = colorScheme == .dark ? 0.32 : 0.22
        return RoundedRectangle(cornerRadius: Layout.rowCornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(opacity))
#endif
    }

    private func scheduleDetailReveal(forceReset: Bool) {
        detailWorkItem?.cancel()
        detailWorkItem = nil
        if forceReset {
            detailUnlocked = false
            if isDetailVisible {
                withAnimation(.easeOut(duration: 0.12)) {
                    isDetailVisible = false
                }
            } else {
                isDetailVisible = false
            }
        } else if detailUnlocked {
            isDetailVisible = selectedSuggestion != nil
            return
        }
        guard !detailUnlocked, selectedSuggestion != nil else { return }
        let workItem = DispatchWorkItem {
            detailUnlocked = true
            withAnimation(.easeOut(duration: 0.2)) {
                isDetailVisible = true
            }
        }
        detailWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.detailRevealDelay, execute: workItem)
    }

    private func cancelDetailReveal() {
        detailWorkItem?.cancel()
        detailWorkItem = nil
        isDetailVisible = false
        detailUnlocked = false
    }
}

struct AutoCompletionDetailView: View {
    let suggestion: SQLAutoCompletionSuggestion

    private enum Layout {
        static let cornerRadius: CGFloat = 14
        static let badgeCornerRadius: CGFloat = 10
        static let columnSpacing: CGFloat = 4
        static let columnBadgeCornerRadius: CGFloat = 6
        static let columnBadgePadding = EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
        static let headerSpacing: CGFloat = 6
        static let maxColumnListHeight: CGFloat = 180
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            contentBody
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailBackground)
        .overlay(detailOverlay)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch suggestion.kind {
        case .table, .view, .materializedView:
            tableDetail
        case .column:
            columnDetail
        default:
            genericDetail
        }
    }

    private var header: some View {
        HStack(spacing: Layout.headerSpacing) {
            Text(suggestion.displayKindTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.primary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var tableDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let schema = suggestion.origin?.schema, let name = suggestion.origin?.object {
                HStack(spacing: 6) {
                    schemaChip(schema)
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
            }

            if let columns = suggestion.tableColumns, !columns.isEmpty {
                ColumnListView(columns: columns)
            } else {
                Text("No columns available")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var columnDetail: some View {
        if let dataType = suggestion.dataType, !dataType.isEmpty {
            Text(dataType)
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(Color.secondary)
        } else {
            Text("Column")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }

    @ViewBuilder
    private var genericDetail: some View {
        if let objectPath = suggestion.displayObjectPath {
            Text(objectPath)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
        }
    }

    private func badge(text: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(serverBadgeBackground)
    }

    private func schemaChip(_ schema: String) -> some View {
        HStack(spacing: 5) {
            Image("schema")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text(schema)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
    }

    private var tableBadgeText: String? {
        guard let origin = suggestion.origin else { return nil }
        return origin.object?.isEmpty == false ? origin.object : nil
    }

    @ViewBuilder
    private var serverBadgeBackground: some View {
#if os(macOS)
        GlassBackground(material: .menu, blendingMode: .withinWindow, emphasized: true)
            .clipShape(Capsule(style: .continuous))
#else
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.85))
#endif
    }

    private struct ColumnListView: View {
        let columns: [SQLAutoCompletionSuggestion.TableColumn]
        @State private var contentHeight: CGFloat = 0

        var body: some View {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Layout.columnSpacing) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            HStack(spacing: 6) {
                                Text(column.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.primary)

                                Spacer(minLength: 10)

                                Text(formatDataType(column.dataType))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .padding(Layout.columnBadgePadding)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                    )
                            }
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ColumnContentHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .frame(maxHeight: Layout.maxColumnListHeight)

                if contentHeight > Layout.maxColumnListHeight {
                    LinearGradient(colors: [Color.clear, Color.primary.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                        .overlay(
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                                .padding(.bottom, 6),
                            alignment: .bottom
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: Layout.maxColumnListHeight)
            .onPreferenceChange(ColumnContentHeightKey.self) { contentHeight = $0 }
        }

        private func formatDataType(_ dataType: String) -> String {
            var formatted = dataType
            if formatted.contains("with time zone") {
                formatted = formatted.replacingOccurrences(of: " with time zone", with: "tz")
            }
            if formatted.contains("without time zone") {
                formatted = formatted.replacingOccurrences(of: " without time zone", with: "")
            }
            return formatted
        }
    }

    private struct ColumnContentHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

#if os(macOS)
    private var detailBackground: some View { Color.clear }

    private var detailOverlay: some View { EmptyView() }
#else
    private var detailBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.95))
    }

    private var detailOverlay: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
    }
#endif
}

#if os(macOS)
private struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = emphasized
        nsView.state = .active
    }
}
#endif
