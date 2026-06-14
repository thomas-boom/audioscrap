import SwiftUI
import AppKit

final class WindowManager: NSObject {
    static let shared = WindowManager()

    private(set) var windows: [NSWindow] = []

    func open<V: View>(_ view: V, title: String, size: NSSize = NSSize(width: 520, height: 420)) {
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windows.append(window)

        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: window)
    }

    @objc private func windowWillClose(_ note: Notification) {
        guard let win = note.object as? NSWindow else { return }
        if let idx = windows.firstIndex(of: win) {
            windows.remove(at: idx)
        }
    }
}
