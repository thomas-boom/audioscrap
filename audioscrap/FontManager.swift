//
//  FontManager.swift
//  audioscrap
//
//  Registers bundled fonts found in the `Fonts/` resource folder at app launch.
//  Falls back to an installed system font if the bundled font isn't present.
//

import Foundation
import AppKit
import CoreText

enum FontManager {
    private static var registeredPostScriptNames: [String] = []

    /// Returns a preferred PostScript name for the app font.
    /// Priority:
    /// 1. First registered bundled font (Fonts/)
    /// 2. System-installed "Monaspace Krypton" if present
    /// 3. Fallback to system monospaced font
    static var preferredFontPostScriptName: String {
        if let first = registeredPostScriptNames.first {
            return first
        }

        let candidate = "Monaspace Krypton"
        if NSFont(name: candidate, size: 12) != nil {
            return candidate
        }

        return NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular).fontName
    }

    /// Register any `.ttf`/`.otf` fonts placed in the bundle subdirectory `Fonts/`.
    static func registerBundledFonts() {
        let exts = ["ttf", "otf"]

        for ext in exts {
            guard let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") else { continue }
            for url in urls {
                var error: Unmanaged<CFError>? = nil
                if CTFontManagerRegisterFontsForURL(url as CFURL, CTFontManagerScope.process, &error) {
                    if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
                        for desc in descriptors {
                            if let psName = CTFontDescriptorCopyAttribute(desc, kCTFontNameAttribute) as? String {
                                registeredPostScriptNames.append(psName)
                            } else if let family = CTFontDescriptorCopyAttribute(desc, kCTFontFamilyNameAttribute) as? String {
                                registeredPostScriptNames.append(family)
                            }
                        }
                    }
                } else {
                    if let err = error?.takeRetainedValue() {
                        NSLog("Font registration error for \(url.lastPathComponent): \(err)")
                    } else {
                        NSLog("Failed to register font at \(url)")
                    }
                }
            }
        }
    }

    static func availableBundledPostScriptNames() -> [String] {
        return registeredPostScriptNames
    }
}
