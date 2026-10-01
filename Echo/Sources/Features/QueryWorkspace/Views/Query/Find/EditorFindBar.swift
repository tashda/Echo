import SwiftUI

/// Round 28.12 (FB5) and 28.13: the find bar: a glass capsule with the search, the Selection button
/// (SS4) and the count, Replace opening inside it with the chevron (RP1, AN1), and ‹ › × as glass
/// circles beside it. Return finds the next match; in Replace it replaces and moves on (RK0).
struct EditorFindBar: View {
    @Bindable var find: EditorFind

    @Environment(\.echoMotion) private var motion
    @FocusState private var focusedField: Field?

    enum Field { case find, replace }

    var body: some View {
        GlassEffectContainer(spacing: SpacingTokens.xs) {
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    findRow
                    if find.isReplaceOpen { replaceRow.transition(.opacity) }
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.xs)
                .frame(width: LayoutTokens.EditorGutter.findBarWidth, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: SpacingTokens.lg, style: .continuous))
                circle("chevron.left", help: "Previous (⇧⌘G)") { find.onPrevious?() }
                circle("chevron.right", help: "Next (⌘G)") { find.onNext?() }
                circle("xmark", help: "Done (Escape)") { find.onClose?() }
            }
        }
        .font(TypographyTokens.detail)
        .animation(motion.standard, value: find.isReplaceOpen)
        .onExitCommand { find.onClose?() }
        .onChange(of: find.focusRequest, initial: true) { _, _ in focusedField = .find }
    }

    private var findRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button {
                find.isReplaceOpen.toggle()
                if find.isReplaceOpen { focusedField = .replace }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(find.isReplaceOpen ? 90 : 0))
                    .frame(width: SpacingTokens.sm, height: SpacingTokens.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(find.isReplaceOpen ? "Hide Replace" : "Show Replace (⌥⌘F)")
            optionsMenu
            TextField("Find", text: $find.query, prompt: Text("Find"))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .find)
                .onSubmit { find.onNext?() }
            if find.scope != nil {
                Button("Selection") { find.isScopeOn.toggle() }
                    .buttonStyle(.plain)
                    .foregroundStyle(find.isScopeOn ? ColorTokens.Text.onFill : ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.micro)
                    .background(find.isScopeOn ? ColorTokens.accent : ColorTokens.Text.primary.opacity(0.08), in: Capsule())
                    .help(find.isScopeOn ? "Searching the selection; click to search the whole script" : "Search only the selection")
            }
            Text(find.countText).foregroundStyle(ColorTokens.Text.secondary).monospacedDigit().fixedSize()
        }
    }

    /// O0: Match Case and Whole Words in the magnifier's menu.
    private var optionsMenu: some View {
        Menu {
            Toggle("Match Case", isOn: $find.matchCase)
            Toggle("Whole Words", isOn: $find.wholeWords)
        } label: {
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var replaceRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Color.clear.frame(width: SpacingTokens.sm, height: 1)
            Image(systemName: "arrow.2.squarepath").foregroundStyle(ColorTokens.Text.secondary)
            TextField("Replace", text: $find.replacement, prompt: Text("Replace with"))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .replace)
                .onSubmit { find.onReplace?() }
            Button("Replace") { find.onReplace?() }
                .buttonStyle(.glass).controlSize(.small).disabled(find.matches.isEmpty)
            Button("Replace All") { find.onReplaceAll?() }
                .buttonStyle(.glassProminent).controlSize(.small).disabled(find.matches.isEmpty)
        }
    }

    private func circle(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: SpacingTokens.xl, height: SpacingTokens.xl)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(help)
    }
}
