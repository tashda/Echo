import SwiftUI

/// Round 43.4 (TC0): the template of a settings page. A live preview pinned above the grouped
/// settings while they scroll (43.1, PV1), and an optional Reset This Page at the bottom with a
/// confirmation (43.5, RP0). Pages with nothing to show use the initializer without a preview.
public struct SettingsPage<Preview: View, Sections: View>: View {
    private let previewHeight: CGFloat
    private let resetPage: (() -> Void)?
    @ViewBuilder private let preview: () -> Preview
    @ViewBuilder private let sections: () -> Sections
    @State private var confirmsReset = false

    public init(
        previewHeight: CGFloat = 170,
        resetPage: (() -> Void)? = nil,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder sections: @escaping () -> Sections
    ) {
        self.previewHeight = previewHeight
        self.resetPage = resetPage
        self.preview = preview
        self.sections = sections
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.none) {
            if Preview.self != EmptyView.self {
                preview()
                    .frame(height: previewHeight)
                    .padding([.horizontal, .top], SpacingTokens.md)
            }
            Form {
                sections()
                if resetPage != nil {
                    Section {
                        Button("Reset This Page", role: .destructive) { confirmsReset = true }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .confirmationDialog("Reset this page to its defaults?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { resetPage?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every setting on this page goes back to its default.")
        }
    }
}

extension SettingsPage where Preview == EmptyView {
    public init(resetPage: (() -> Void)? = nil, @ViewBuilder sections: @escaping () -> Sections) {
        self.init(resetPage: resetPage, preview: { EmptyView() }, sections: sections)
    }
}
