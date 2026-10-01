import SwiftUI

/// Current rail for the As built page; frozen Rail decision retains its original two-pill specimen.
struct WindowRailSpecimen: View {
    private let itemSize = SpacingTokens.xl + SpacingTokens.micro
    @Binding var selected: String?
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack {
            VStack(spacing: LayoutTokens.Rail.itemSpacing) {
                ForEach(LabServer.samples) { server in
                    Button { withAnimation(motion.standard) { selected = server.id } } label: {
                        Text(server.monogram)
                            .font(TypographyTokens.standard.weight(selected == server.id ? .bold : .semibold))
                            .foregroundStyle(server.color)
                            .frame(width: itemSize, height: itemSize)
                            .background {
                                if selected == server.id {
                                    Circle().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection)
                                        .padding(LayoutTokens.Rail.selectionInset)
                                }
                            }
                    }.buttonStyle(.plain)
                }
                Image(systemName: "plus").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: itemSize, height: itemSize)
            }.padding(LayoutTokens.Rail.pillPadding).glassEffect(.regular, in: .capsule)
            Spacer(minLength: SpacingTokens.none)
        }.frame(width: LayoutTokens.Rail.width(itemSize: itemSize))
    }
}
