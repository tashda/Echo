import SwiftUI
import StageCore

/// What a round implements. The round package is the only code compiled per Proposal; everything else is prebuilt.
///
/// A specimen reads its look from the environment: `stageCornerRadius`, `stageTextScale`, `stageReduceMotion`,
/// `stageIncreaseContrast`, `stagePalette`, and `stageTransportTime` for motion. It must draw the same sample data in every
/// scenario and must not show its own title (the column header already names it).
@MainActor
public protocol SpecimenProvider {
    /// The view for one specimen id in one scenario. `controls` maps control id to choice id (the preview, a Mix, or a pinned Mix).
    func specimenView(id: String, scenario: String, controls: [String: String]) -> AnyView

    /// The size the specimen is designed at, in points. 100% zoom draws it at exactly this size.
    func designSize(for id: String) -> CGSize

    /// Height in points of the specimen in a scenario, for the Matrix difference rule (outlined when it differs from Echo today by
    /// more than 14pt). Return `nil` when unknown; such a cell is never outlined.
    func measuredHeight(id: String, scenario: String, controls: [String: String]) -> Double?

    /// Measurements drawn when Redlines is on, in the specimen's own units.
    func redlines(id: String, scenario: String, controls: [String: String]) -> [StageRedline]

    /// Length of the specimen's motion in seconds. `nil` for a still specimen (no transport bar).
    func motionDuration(id: String, scenario: String, controls: [String: String]) -> Double?

    /// When tagged parts appear and go away, drawn under the scrubber.
    func motionMarks(id: String, scenario: String, controls: [String: String]) -> [StageMotionMark]

    /// `false` makes the stage show "this specimen failed" in its place, with a report button (decision H21).
    func hasSpecimen(id: String) -> Bool
}

extension SpecimenProvider {
    public func measuredHeight(id: String, scenario: String, controls: [String: String]) -> Double? { nil }
    public func redlines(id: String, scenario: String, controls: [String: String]) -> [StageRedline] { [] }
    public func motionDuration(id: String, scenario: String, controls: [String: String]) -> Double? { nil }
    public func motionMarks(id: String, scenario: String, controls: [String: String]) -> [StageMotionMark] { [] }
    public func hasSpecimen(id: String) -> Bool { true }
}
