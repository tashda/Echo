import AppKit

extension Bundle {
    var iconImage: NSImage? {
        if let iconName = object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            return NSImage(named: iconName)
        }
        if let iconsDict = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primary = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last {
            return NSImage(named: name)
        }
        return nil
    }

    var bundleName: String? {
        object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
    }
}
