#if DEBUG
import SwiftUI

/// Round 10: the database switcher that opens from the footer's server · database pill. The
/// card is Echo's real `DatabaseSwitcherCard`; the layout and the opening are the options.
enum LabSwitcherLook: String, CaseIterable, Identifiable {
    case covers = "L1 Covers the chip"
    case above = "L2 Above the chip"
    case titled = "L3 Above, with title"
    var id: String { rawValue }
}

enum LabSwitcherMotion: String, CaseIterable, Identifiable {
    case grow = "A1 Grow from pill"
    case rise = "A2 Rise"
    case morph = "A3 Morph (today)"
    case unfold = "A4 Unfold"
    var id: String { rawValue }
}

struct LabSwitcherStage: View {
    @State private var look: LabSwitcherLook = .above
    @State private var motion: LabSwitcherMotion = .grow
    @State private var isOpen = false
    @State private var database = "employees"
    @Namespace private var morph
    @Environment(\.echoMotion) private var echoMotion

    private let databases = ["employees", "k", "lego", "postgres", "reporting", "staging"]

    var body: some View {
        LabStage(title: "Database switcher: click the pill") {
            LabPicker(title: "Layout", selection: $look, options: LabSwitcherLook.allCases)
            LabPicker(title: "Opening", selection: $motion, options: LabSwitcherMotion.allCases)
        } content: {
            LabCard {
                ZStack(alignment: .bottomLeading) {
                    LabEditorText()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    footer
                }
            }
            .frame(width: 760, height: 420)
            .padding(24)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onChange(of: look) { _, _ in isOpen = false }
        .onChange(of: motion) { _, _ in isOpen = false }
    }

    private var chipText: String { "postgres18 · \(database)" }

    private var footer: some View {
        HStack(spacing: SpacingTokens.xs) {
            ZStack(alignment: .bottomLeading) {
                if !(isOpen && look == .covers) {
                    chip
                }
                if isOpen {
                    card
                        .padding(.bottom, look == .covers ? 0 : LayoutTokens.Footer.chipHeight + SpacingTokens.xs)
                        .zIndex(1)
                }
            }
            .frame(height: LayoutTokens.Footer.chipHeight, alignment: .bottomLeading)
            .zIndex(1)
            if !(isOpen && look == .covers) {
                HStack(spacing: 0) {
                    Image(systemName: "tablecells").frame(width: 28)
                    Image(systemName: "text.bubble").foregroundStyle(.secondary).frame(width: 28)
                }
                .font(TypographyTokens.detail)
                .frame(height: LayoutTokens.Footer.chipHeight)
                .glassEffect(.regular, in: .capsule)
            }
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xs)
    }

    @ViewBuilder
    private var chip: some View {
        let label = Button { toggle() } label: {
            Text(chipText)
                .font(TypographyTokens.detail)
                .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
                .frame(height: LayoutTokens.Footer.chipHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        if motion == .morph {
            label.matchedGeometryEffect(id: "switcher", in: morph)
        } else {
            label
        }
    }

    @ViewBuilder
    private var card: some View {
        let content = DatabaseSwitcherCard(
            databases: databases,
            currentDatabase: database,
            chipLabel: chipText,
            onSelect: { selected in
                database = selected
                toggle()
            },
            onDismiss: { if isOpen { toggle() } },
            showsChipLabel: look == .covers,
            title: look == .titled ? "postgres18" : nil
        )
        .background {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.cornerRadius))
        }
        switch motion {
        case .grow:
            content.transition(.scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))
        case .rise:
            content.transition(.offset(y: SpacingTokens.sm).combined(with: .opacity))
        case .morph:
            content.matchedGeometryEffect(id: "switcher", in: morph)
        case .unfold:
            content.transition(.modifier(
                active: LabUnfold(progress: 0),
                identity: LabUnfold(progress: 1)
            ))
        }
    }

    private func toggle() {
        withAnimation(echoMotion.standard) { isOpen.toggle() }
    }
}

/// A4: the card's height unfolds upward from the pill while it fades in.
private struct LabUnfold: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: max(progress, 0.05), anchor: .bottom)
            .opacity(Double(progress))
    }
}
#endif
