import SwiftUI

/// Round 9, section 4: the tab bar, today a grey plate with a separate grey +.
enum LabTabBar: String, CaseIterable, Identifiable {
    case today = "Today"
    case glass = "TB1 Glass capsule"
    case toolbar = "TB3 In the toolbar"
    case hugging = "TB4 Hugging tabs"
    var id: String { rawValue }
}

struct LabTabsStage: View {
    @State private var style: LabTabBar = .glass
    @State private var tabs = ["Query 1 · Dev_DM", "Query 2 · Dev_DM", "Query 3"]
    @State private var active = 0
    @Namespace private var selection

    var body: some View {
        LabStage(title: "Tab bar: click tabs and +") {
            LabPicker(title: "Tab bar", selection: $style, options: LabTabBar.allCases)
        } content: {
            VStack(spacing: 6) {
                toolbar
                if style != .toolbar {
                    tabBar
                }
                LabCard { LabEditorText() }
            }
            .padding(6)
            .frame(width: 760, height: 300)
            .background(Color(nsColor: .windowBackgroundColor))
            .padding(24)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: style)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: active)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: tabs)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 11, height: 11) }
            }
            .padding(.leading, 6)
            Image(systemName: "sidebar.left")
                .frame(width: 30, height: 28)
                .glassEffect(.regular, in: .capsule)
            if style == .toolbar {
                tabBar
            } else {
                Spacer()
            }
            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .frame(width: 36, height: 28)
                .glassEffect(.regular.tint(.accentColor), in: .capsule)
        }
        .frame(height: 34)
    }

    @ViewBuilder
    private var tabBar: some View {
        switch style {
        case .today:
            HStack(spacing: 6) {
                HStack(spacing: 2) { tabButtons(hugging: false) }
                    .padding(3)
                    .background(Color.primary.opacity(0.07), in: .rect(cornerRadius: 9))
                plusButton
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.07), in: .circle)
            }
        case .glass, .toolbar:
            GlassEffectContainer {
                HStack(spacing: 2) {
                    tabButtons(hugging: false)
                    plusButton.frame(width: 28)
                }
                .padding(3)
                .glassEffect(.regular, in: .capsule)
            }
        case .hugging:
            HStack {
                GlassEffectContainer {
                    HStack(spacing: 2) {
                        tabButtons(hugging: true)
                        plusButton.frame(width: 28)
                    }
                    .padding(3)
                    .glassEffect(.regular, in: .capsule)
                }
                Spacer()
            }
        }
    }

    /// Real buttons (TFIX): a click selects at once, with no wait to rule out a drag.
    private func tabButtons(hugging: Bool) -> some View {
        ForEach(Array(tabs.enumerated()), id: \.element) { index, title in
            Button { active = index } label: {
                Text(title)
                    .font(.system(size: 11.5, weight: index == active ? .medium : .regular))
                    .foregroundStyle(index == active ? .primary : .secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: hugging ? nil : .infinity)
                    .frame(height: 24)
                    .background {
                        if index == active {
                            Capsule()
                                .fill(Color(nsColor: .textBackgroundColor))
                                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 0.5)
                                .matchedGeometryEffect(id: "active", in: selection)
                        }
                    }
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private var plusButton: some View {
        Button {
            tabs.append("Query \(tabs.count + 1)")
            active = tabs.count - 1
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help("New Query Tab")
    }
}
