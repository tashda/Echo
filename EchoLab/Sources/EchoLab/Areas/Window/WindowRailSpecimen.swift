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
            }.padding(LayoutTokens.Rail.pillPadding).glassEffect(.regular, in: .capsule)
            // Connect to a Server: its own circle (round 55).
            Image(systemName: LayoutTokens.Rail.connectSymbol).font(.system(size: LayoutTokens.Rail.toolSymbolSize)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: itemSize, height: itemSize)
                .padding(LayoutTokens.Rail.pillPadding).glassEffect(.regular, in: .circle)
            Spacer(minLength: SpacingTokens.none)
        }.frame(width: LayoutTokens.Rail.width(itemSize: itemSize))
    }
}
