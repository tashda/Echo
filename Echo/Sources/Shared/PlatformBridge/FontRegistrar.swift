import Foundation
import CoreText
import AppKit
import OSLog

/// Registers bundled custom fonts so they are available throughout the app
enum FontRegistrar {
    private static let fontSubdirectory = "Fonts"
    private nonisolated(unsafe) static var hasRegistered = false
    private static let lock = NSLock()

    static func registerBundledFonts() {
        lock.lock()
        defer { lock.unlock() }
        if hasRegistered { return }

        var collected: [URL] = []

        if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: fontSubdirectory) {
            collected.append(contentsOf: bundleURLs)
        }

        if let resourceRoot = Bundle.main.resourceURL?.appendingPathComponent(fontSubdirectory, isDirectory: true),
           FileManager.default.fileExists(atPath: resourceRoot.path) {
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: resourceRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                collected.append(contentsOf: directoryContents.filter { $0.pathExtension.lowercased() == "ttf" })
            } catch {
                Logger.fonts.error("Failed to enumerate Fonts directory: \(error)")
            }
        }

        let urls = Array(Set(collected))
        guard !urls.isEmpty else {
            Logger.fonts.warning("No font URLs found in \(fontSubdirectory)")
            return
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success {
                if let cfError = error?.takeRetainedValue() {
                    let nsError = cfError as Error as NSError
                    let alreadyRegisteredCode = Int(CTFontManagerError.alreadyRegistered.rawValue)
                    let domain = nsError.domain
                    let code = nsError.code
                    if domain == kCTFontManagerErrorDomain as String && code == alreadyRegisteredCode {
                        Logger.fonts.debug("Font already registered: \(url.lastPathComponent)")
                    } else {
                        Logger.fonts.error("Failed to register font at \(url.lastPathComponent): \(cfError)")
                    }
                }
            } else {
                Logger.fonts.debug("Registered font: \(url.lastPathComponent)")
            }
        }

        hasRegistered = true
    }
}
