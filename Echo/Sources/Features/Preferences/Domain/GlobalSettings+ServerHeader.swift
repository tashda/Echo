import Foundation

extension GlobalSettings {
    /// The header style from saved settings. Settings saved before round 53 have no
    /// `serverHeaderLook`; there the wash was only ever the default, so it moves to the new default
    /// once. Every other saved style, and any later choice of the wash, stays.
    nonisolated static func decodedServerHeaderStyle(_ saved: ServerHeaderStyle?, hasLook: Bool) -> ServerHeaderStyle {
        guard let saved else { return .titleBanner }
        return saved == .wash && !hasLook ? .titleBanner : saved
    }
}
