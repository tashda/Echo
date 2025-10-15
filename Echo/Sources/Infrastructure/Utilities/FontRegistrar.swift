import Foundation
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Registers bundled custom fonts so they are available throughout the app
enum FontRegistrar {
    private static let fontSubdirectory = "Fonts"
    private static var hasRegistered = false
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
                print("[FontRegistrar] Failed to enumerate Fonts directory: \(error)")
            }
        }

        let urls = Array(Set(collected))
        guard !urls.isEmpty else {
            print("[FontRegistrar] No font URLs found in \(fontSubdirectory)")
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
                        #if DEBUG
                        print("[FontRegistrar] Font already registered: \(url.lastPathComponent)")
                        #endif
                    } else {
                        print("[FontRegistrar] Failed to register font at \(url.lastPathComponent): \(cfError)")
                    }
                }
            } else {
                #if DEBUG
                if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
                    let names = descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
                    print("[FontRegistrar] Registered fonts: \(names)")
                }
                #endif
            }
        }

        hasRegistered = true
    }
}
