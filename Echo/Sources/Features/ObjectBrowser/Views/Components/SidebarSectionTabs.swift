import AppKit
import SwiftUI

struct SidebarSectionTabs: View {
    @Binding var selection: SidebarMenu.NavSection

    var body: some View {
        SidebarSectionTabsControl(selection: $selection)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: LayoutTokens.Sidebar.navigationControlHeight)
    }
}

struct SidebarSectionTabsControl: NSViewRepresentable {
    @Binding var selection: SidebarMenu.NavSection

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = Self.makeControl(
            target: context.coordinator,
            action: #selector(Coordinator.selectionDidChange(_:))
        )
        configureSegments(on: control)
        return control
    }

    static func makeControl(target: AnyObject?, action: Selector?) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            images: SidebarMenu.NavSection.allCases.map(\.tabImage),
            trackingMode: .selectOne,
            target: target,
            action: action
        )
        control.segmentStyle = .automatic
        applyNavigationAppearance(to: control)
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.defaultLow, for: .vertical)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        Self.applyNavigationAppearance(to: control)
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        configureSegments(on: control)
        control.selectedSegment = SidebarMenu.NavSection.allCases.firstIndex(of: selection) ?? 0
    }

    private static func applyNavigationAppearance(to control: NSSegmentedControl) {
        if #available(macOS 27.0, *) {
            control.role = .tabs
        }
        control.borderShape = .capsule
    }

    private func configureSegments(on control: NSSegmentedControl) {
        let sections = SidebarMenu.NavSection.allCases
        if control.segmentCount != sections.count {
            control.segmentCount = sections.count
        }

        for (index, section) in sections.enumerated() {
            control.setImage(section.tabImage, forSegment: index)
            control.setImageScaling(.scaleProportionallyDown, forSegment: index)
            control.setToolTip(section.displayName, forSegment: index)
            control.setTag(index, forSegment: index)
            control.setWidth(0, forSegment: index)
            control.setEnabled(true, forSegment: index)
        }
    }

    final class Coordinator: NSObject {
        var selection: Binding<SidebarMenu.NavSection>

        init(selection: Binding<SidebarMenu.NavSection>) {
            self.selection = selection
        }

        @MainActor
        @objc
        func selectionDidChange(_ sender: NSSegmentedControl) {
            let sections = SidebarMenu.NavSection.allCases
            guard sections.indices.contains(sender.selectedSegment) else {
                return
            }
            selection.wrappedValue = sections[sender.selectedSegment]
        }
    }
}

private extension SidebarMenu.NavSection {
    var tabImage: NSImage {
        guard let image = NSImage(systemSymbolName: icon, accessibilityDescription: displayName) else {
            return NSImage()
        }
        image.isTemplate = true
        return image
    }
}

#if DEBUG
private struct SidebarSectionTabsPreviewHost: View {
    @State private var selection: SidebarMenu.NavSection = .folder

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            SidebarSectionTabs(selection: $selection)
                .padding(.horizontal, LayoutTokens.Sidebar.navigationHorizontalPadding)

            Text(selection.displayName)
                .font(TypographyTokens.headline)
                .foregroundStyle(ColorTokens.Text.primary)
                .padding(.horizontal, SpacingTokens.sm)

            Spacer()
        }
        .frame(width: 420, height: 260)
        .padding(.top, SpacingTokens.lg2)
        .background(ColorTokens.Background.sidebar)
    }
}

#Preview("Sidebar Section Tabs") {
    SidebarSectionTabsPreviewHost()
}
#endif
