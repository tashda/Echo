import SwiftUI

/// How Echo is checked against a round once it is built: which states of the accepted exhibit to
/// capture, which tagged part frames the comparison, and which differences are expected. Echo's
/// specimen for the same page id must draw the same states (see `EchoLab/Scripts/verify-round.py`).
struct RoundConformance {
    struct State {
        let id: String
        /// What the state shows, for the report.
        let title: String
        /// Seconds after it is shown that the screenshot is taken (after arrival animations).
        var settle: Double = 1.5
        /// Seconds to keep watching for timelines (a toast going away); 0 to stop at the screenshot.
        var observe: Double = 0
    }

    var states: [State]
    /// The tag of the part being judged; parts are compared relative to its top-left corner and
    /// the screenshots are cropped to it.
    let subject: String
    /// Differences that are expected, with the reason (a fixture gap, for example): a part name
    /// exempts that part, `pixels:<part>` only leaves its pixels out of the score. The report lists
    /// them as expected instead of failing.
    var knownDifferences: [String: String] = [:]
}

extension EnvironmentValues {
    /// The conformance state an exhibit is being captured in, nil in the lab itself. An exhibit
    /// with conformance states reads it on appear to put itself in that state.
    @Entry var labConformanceState: String?
}
