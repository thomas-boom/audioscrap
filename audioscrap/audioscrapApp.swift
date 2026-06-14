//
//  audioscrapApp.swift
//  audioscrap
//
//  Created by Thomas Boom on 12/7/25.
//

import SwiftUI
import AppKit

@main
struct audioscrapApp: App {
    init() {
        // Register any bundled fonts placed in `Fonts/` so they can be used via Font.custom(...)
        FontManager.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, Font.custom(FontManager.preferredFontPostScriptName, size: NSFont.systemFontSize))
        }
    }
}
