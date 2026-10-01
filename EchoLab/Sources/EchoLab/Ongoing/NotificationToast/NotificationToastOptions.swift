import SwiftUI

/// Round 18's choices. Names are stable: the owner's picks refer to them.
enum NTLayout: String, CaseIterable {
    case oneLine = "L1 · One line (today)"
    case titleDetail = "L2 · Title and detail"
    case pill = "L3 · Compact pill"
    case withServer = "L4 · With the server"
}

enum NTActions: String, CaseIterable {
    case textLinks = "A1 · Text links (today)"
    case smallButtons = "A2 · Small buttons"
    case icons = "A3 · Icons"
    case none = "A4 · None, click the toast"
}

enum NTDismiss: String, CaseIterable {
    case hoverX = "D1 · × on hover (today)"
    case alwaysX = "D2 · × always"
    case swipe = "D3 · Swipe right"
    case click = "D4 · Click anywhere"
}

enum NTMaterial: String, CaseIterable {
    case glass = "M1 · Liquid Glass (today)"
    case tintedGlass = "M2 · Tinted glass"
    case card = "M3 · Opaque card"
}

enum NTArrival: String, CaseIterable {
    case drop = "E1 · Drop from the top (today)"
    case grow = "E2 · Grow from the corner"
    case slide = "E3 · Slide from the edge"

    var transition: AnyTransition {
        switch self {
        case .drop: .move(edge: .top).combined(with: .opacity)
        case .grow: .scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity)
        case .slide: .move(edge: .trailing).combined(with: .opacity)
        }
    }
}

enum NTStacking: String, CaseIterable {
    case list = "S1 · List of three (today)"
    case deck = "S2 · Deck"
    case newestOnly = "S3 · Newest only, +2"
}

enum NTDuration: String, CaseIterable {
    case three = "T1 · 3 s (today)"
    case five = "T2 · 5 s"
    case eight = "T3 · 8 s"

    var seconds: Double {
        switch self {
        case .three: 3
        case .five: 5
        case .eight: 8
        }
    }
}

/// Everything one exhibit draws with, read from the controls (or fixed, for Echo today).
struct NTOptions: Equatable {
    var layout: NTLayout = .oneLine
    var actions: NTActions = .textLinks
    var dismiss: NTDismiss = .hoverX
    var material: NTMaterial = .glass
    var arrival: NTArrival = .drop
    var stacking: NTStacking = .list
    var duration: NTDuration = .three

    static let today = NTOptions()

    init() {}

    @MainActor init(values: RoundValues) {
        layout = NTLayout(rawValue: values["layout"]) ?? .titleDetail
        actions = NTActions(rawValue: values["actions"]) ?? .smallButtons
        dismiss = NTDismiss(rawValue: values["dismiss"]) ?? .swipe
        material = NTMaterial(rawValue: values["material"]) ?? .glass
        arrival = NTArrival(rawValue: values["arrival"]) ?? .drop
        stacking = NTStacking(rawValue: values["stacking"]) ?? .deck
        duration = NTDuration(rawValue: values["duration"]) ?? .five
    }
}
