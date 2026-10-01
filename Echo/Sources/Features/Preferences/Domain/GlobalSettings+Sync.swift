import Foundation

/// Round 43.5 (SY0): settings sync everything except what belongs to this Mac: folders and tool
/// paths. (Window sizes live in the window's own saved frame, which settings never held.)
extension GlobalSettings {
    /// What goes to the cloud: this Mac's paths left out.
    func withoutThisMacsValues() -> GlobalSettings {
        var copy = self
        copy.resultSpoolCustomLocation = nil
        copy.pgToolCustomPath = nil
        copy.mysqlToolCustomPath = nil
        return copy
    }

    /// What arrives from the cloud, with this Mac's own paths kept.
    func keepingThisMacsValues(from local: GlobalSettings) -> GlobalSettings {
        var copy = self
        copy.resultSpoolCustomLocation = local.resultSpoolCustomLocation
        copy.pgToolCustomPath = local.pgToolCustomPath
        copy.mysqlToolCustomPath = local.mysqlToolCustomPath
        return copy
    }
}
