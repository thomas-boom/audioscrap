#if canImport(SwiftWin32)
import SwiftWin32
#else
import SwiftUI
#endif

import Foundation

@main
struct AudioScrapWindowsApp {
    static func main() {
        #if canImport(SwiftWin32)
        let app = Application.shared
        let window = Window("audioscrap - Windows")
        let content = ContentView()
        window.rootView = AnyView(content)
        window.center()
        window.makeKeyAndVisible()
        app.run()
        #else
        // Fallback: run nothing useful on non-Windows builds in this scaffold.
        print("This scaffold targets Windows using SwiftWin32.")
        #endif
    }
}
