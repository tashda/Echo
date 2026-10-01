import Foundation

/// Something the footer's rows popover asks the results card to do (round 41.5, PR0): the results
/// card owns the sort order and the export sheet, so it carries these out.
struct ResultsActionRequest: Equatable {
    enum Kind: Equatable {
        /// Opens the export sheet for the result set on screen.
        case export
        /// Copies every row of the result set on screen, with its column names, as tab-separated text.
        case copyAll
    }

    let kind: Kind
    let id = UUID()
}
