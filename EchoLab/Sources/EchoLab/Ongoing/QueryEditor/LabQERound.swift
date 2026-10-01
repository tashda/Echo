import SwiftUI

/// Round 28: the pieces every editor page shares: Echo today, the proposal, a side-by-side
/// gallery of one control's choices, and the playground controls (what the editor shows, and
/// whether the rest of the editor is as today or as recommended).
@MainActor
enum LabQERound {
    static let width: CGFloat = 560
    static let height: CGFloat = 400

    static func sceneControl(default value: LabQESceneChoice) -> RoundSpec.Control {
        .of("scene", "The editor shows", LabQESceneChoice.self, default: value)
    }

    static let baseControl: RoundSpec.Control = .of("base", "Rest of the editor", LabQEBase.self, default: .recommended)

    static let runAgain = RoundSpec.Action(id: "run", title: "Run again", symbol: "play.fill") { values in
        values["scene"] = values["scene"] == LabQESceneChoice.afterError.rawValue ? LabQESceneChoice.afterError.rawValue : LabQESceneChoice.afterRun.rawValue
        LabQEReplay.shared.runs += 1
    }

    static func scene(_ values: RoundValues, _ fallback: LabQESceneChoice) -> LabQEScene {
        (LabQESceneChoice(rawValue: values["scene"]) ?? fallback).scene
    }

    static func today(_ summary: String, scene fallback: LabQESceneChoice, outlineEdge: Bool = false,
                      hints: LabQEHintsPlace? = nil, before28: Bool = false) -> RoundSpec.Exhibit {
        .init(id: "today", title: before28 ? "Echo before round 28" : "Echo today", summary: summary, isEchoToday: true,
              designWidth: width, designHeight: height) { values in
            LabQEEditor(style: before28 ? .before28 : .today, scene: scene(values, fallback), outlineEdge: outlineEdge, hints: hints)
        }
    }

    static func proposal(_ summary: String, scene fallback: LabQESceneChoice, outlineEdge: Bool = false,
                         hints: ((RoundValues) -> LabQEHintsPlace?)? = nil,
                         sceneFor: (@MainActor (RoundValues) -> LabQEScene)? = nil) -> RoundSpec.Exhibit {
        .init(id: "proposal", title: "Proposal", summary: summary, designWidth: width, designHeight: height) { values in
            LabQEEditor(style: LabQEBase.proposal(values), scene: sceneFor?(values) ?? scene(values, fallback),
                        onZoom: { values["zoom"] = $0.rawValue }, outlineEdge: outlineEdge, hints: hints?(values))
        }
    }

    /// Every choice of one control side by side, each on the proposal.
    static func gallery<E: CaseIterable & RawRepresentable>(
        _ title: String, _ summary: String, _ type: E.Type, _ path: WritableKeyPath<LabQEStyle, E>,
        scene fallback: LabQESceneChoice, id: String = "gallery", addedIn: Int? = nil, only: [E]? = nil,
        cellHeight: CGFloat = LabQEGallery.cellHeight, sceneFor: (@MainActor (RoundValues) -> LabQEScene)? = nil,
        adjust: @escaping (inout LabQEStyle) -> Void = { _ in }
    ) -> RoundSpec.Exhibit where E.RawValue == String {
        let choices = only ?? Array(E.allCases)
        return .init(id: id, title: title, summary: summary, addedIn: addedIn, designWidth: LabQEGallery.width,
                     designHeight: LabQEGallery.height(count: choices.count, cellHeight: cellHeight)) { values in
            LabQEGallery(items: choices.map { choice in
                var style = LabQEBase.proposal(values)
                adjust(&style)
                style[keyPath: path] = choice
                return (choice.rawValue, style)
            }, scene: sceneFor?(values) ?? scene(values, fallback), cellHeight: cellHeight)
        }
    }
}

/// Small editors in a grid, each with its choice's name.
struct LabQEGallery: View {
    static let width: CGFloat = 700
    static let cellHeight: CGFloat = 210
    static func height(count: Int, cellHeight: CGFloat = cellHeight) -> CGFloat {
        CGFloat((count + 1) / 2) * (cellHeight + SpacingTokens.lg) + SpacingTokens.xs
    }

    let items: [(name: String, style: LabQEStyle)]
    let scene: LabQEScene
    var cellHeight: CGFloat = Self.cellHeight

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: SpacingTokens.md), GridItem(.flexible(), spacing: SpacingTokens.md)],
                  alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(item.name).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                    LabQEEditor(style: item.style, scene: scene).frame(height: cellHeight)
                }
            }
        }
        .padding(SpacingTokens.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
