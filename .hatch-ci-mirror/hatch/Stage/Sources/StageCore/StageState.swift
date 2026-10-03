import Foundation

public enum StageMode: String, Codable, CaseIterable {
    case side, overlay, flip, wipe, matrix

    public var title: String {
        switch self {
        case .side: return "Side by side"
        case .overlay: return "Overlay"
        case .flip: return "Flip"
        case .wipe: return "Wipe"
        case .matrix: return "Matrix"
        }
    }

    /// Keys 1 to 5 (decision H20).
    public static func forKey(_ digit: Int) -> StageMode? {
        let all = StageMode.allCases
        guard digit >= 1, digit <= all.count else { return nil }
        return all[digit - 1]
    }

    /// Modes that compare Echo today with one chosen option.
    public var comparesOne: Bool { self == .overlay || self == .flip || self == .wipe }
}

public enum StageAppearance: String, Codable, CaseIterable {
    case light, dark
    public var title: String { self == .light ? "Light" : "Dark" }
}

public enum StageTextSize: String, Codable, CaseIterable {
    case small, standard, large, extraLarge

    public var title: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Default"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        }
    }

    public var scale: Double {
        switch self {
        case .small: return 0.9
        case .standard: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

public enum StageVerdict: String, Codable, CaseIterable {
    case pick, maybe, no
    public var title: String {
        switch self {
        case .pick: return "Pick"
        case .maybe: return "Maybe"
        case .no: return "No"
        }
    }
}

public enum StagePanel: String, Codable, CaseIterable {
    case controls, decision, playground
}

public enum StageSheet: String, Codable, Equatable {
    case accept, sendBack, ask, help
}

public enum StageSendBackReason: String, Codable, CaseIterable {
    /// The raw values are the words Hatch's local API expects.
    case needsMoreOptions = "needs-more-options"
    case changeAnOption = "change-option"
    case differentDirection = "different-direction"
    public var title: String {
        switch self {
        case .needsMoreOptions: return "Needs more options"
        case .changeAnOption: return "Change an option"
        case .differentDirection: return "Different direction"
        }
    }
    public var detail: String {
        switch self {
        case .needsMoreOptions: return "Add options and keep the old ones."
        case .changeAnOption: return "Edit one option."
        case .differentDirection: return "Start from a new angle."
        }
    }
}

/// A note dropped on a specimen. It stores the state it was written in, and clicking it restores that state (decision H13).
public struct StagePin: Codable, Equatable, Identifiable {
    public var id: String
    public var number: Int
    public var text: String
    public var option: String?
    /// Position inside the specimen slot, 0 to 1.
    public var x: Double?
    public var y: Double?
    public var scenario: String
    public var appearance: StageAppearance
    public var corners: Int
    public var zoom: Double
    public init(id: String, number: Int, text: String, option: String?, x: Double?, y: Double?, scenario: String,
                appearance: StageAppearance, corners: Int, zoom: Double) {
        self.id = id; self.number = number; self.text = text; self.option = option; self.x = x; self.y = y
        self.scenario = scenario; self.appearance = appearance; self.corners = corners; self.zoom = zoom
    }
}

/// A Mix column pinned from the answers at one moment (Mix 1, Mix 2; decision H22).
public struct StageMixColumn: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    /// Control id to choice id, frozen when pinned.
    public var controls: [String: String]
    public init(id: String, title: String, controls: [String: String]) {
        self.id = id; self.title = title; self.controls = controls
    }
}

/// Transport bar state for motion specimens (decision H18).
public struct StageTransport: Codable, Equatable {
    public static let speeds: [Double] = [0.25, 0.5, 1, 1.5, 2]
    public static let framesPerSecond: Double = 30

    public var playing: Bool
    /// Seconds into the specimen's timeline.
    public var time: Double
    public var speed: Double
    public var loop: Bool
    /// false until the owner first plays, scrubs or steps. Until then a motion specimen shows its steady state instead of frame 0.
    public var engaged: Bool

    public init(playing: Bool = false, time: Double = 0, speed: Double = 1, loop: Bool = true, engaged: Bool = false) {
        self.playing = playing; self.time = time; self.speed = speed; self.loop = loop; self.engaged = engaged
    }

    /// Moves the playhead by `dt` real seconds. At the end it loops or stops.
    public mutating func advance(by dt: Double, duration: Double) {
        guard playing, duration > 0 else { return }
        var t = time + dt * speed
        if t >= duration {
            if loop { t = t.truncatingRemainder(dividingBy: duration) } else { t = duration; playing = false }
        }
        time = t
    }

    public mutating func scrub(to seconds: Double, duration: Double) {
        engaged = true
        time = min(max(seconds, 0), max(duration, 0))
    }

    /// One frame forward or back. Stepping pauses.
    public mutating func step(frames: Int, duration: Double) {
        playing = false
        scrub(to: time + Double(frames) / StageTransport.framesPerSecond, duration: duration)
    }

    public mutating func togglePlay(duration: Double) {
        engaged = true
        if !playing && time >= duration && duration > 0 { time = 0 }
        playing.toggle()
    }
}

/// Everything the owner has set on the stage. Codable, so it is remembered per ticket.
public struct StageState: Codable, Equatable {
    public var mode: StageMode = .side
    public var appearance: StageAppearance = .light
    public var increaseContrast: Bool = false
    public var corners: Int = 10
    public var textSize: StageTextSize = .standard
    public var reduceMotion: Bool = false
    /// 1.0 is Echo's real size.
    public var zoom: Double = 1.0
    public var scenario: String = "rest"
    public var redlines: Bool = false
    /// Option ids shown as columns. `nil` shows all of them.
    public var shownOptions: [String]? = nil
    /// The option compared with Echo today in Overlay, Flip and Wipe, and shown large in the filmstrip.
    public var selected: String? = nil
    /// false: Echo today, true: the selected option.
    public var flipSide: Bool = false
    public var overlayOpacity: Double = 0.5
    public var wipePosition: Double = 0.5
    public var showLiveMix: Bool = false
    public var pinnedMixes: [StageMixColumn] = []
    public var foldedPanels: Set<StagePanel> = [.playground]
    /// The panels are folded once from the window width on first launch, then the owner decides.
    public var layoutDecided: Bool = false
    /// Control id to choice id: what the preview is showing.
    public var controlValues: [String: String] = [:]
    /// Topic id to the chosen choice id (the owner's answers).
    public var answers: [String: String] = [:]
    public var topicNotes: [String: String] = [:]
    public var needsMore: Set<String> = []
    /// Specimen id to verdict.
    public var verdicts: [String: StageVerdict] = [:]
    public var optionNotes: [String: String] = [:]
    public var generalNote: String = ""
    public var pins: [StagePin] = []
    public var transport: StageTransport = StageTransport()
    public var sheet: StageSheet? = nil
    public var pinMode: Bool = false
    /// Text typed into the Ask sheet is kept here so a closed sheet does not lose it.
    public var askDraft: String = ""
    public var sendBackReason: StageSendBackReason = .changeAnOption
    public var sendBackNote: String = ""
    /// Set by the last Accept or Send back; shown as a banner.
    public var outcome: String? = nil
    /// Why the open sheet cannot be confirmed yet (for example Send back without a note).
    public var formError: String? = nil

    public init() {}

    /// A state for a manifest: preview at the defaults, the first applicable scenario, the first option selected.
    public init(manifest: StageManifest) {
        controlValues = manifest.defaultControlValues
        scenario = manifest.applicableScenarios.first?.id ?? "rest"
        selected = manifest.proposalSpecimens.first?.id
    }

    public func isFolded(_ p: StagePanel) -> Bool { foldedPanels.contains(p) }

    public func controlValue(_ id: String, in manifest: StageManifest) -> String {
        controlValues[id] ?? manifest.control(id)?.defaultChoice ?? ""
    }
}
