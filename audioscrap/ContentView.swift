import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = YTDLPViewModel()
    @State private var customName: String = ""
    @State private var showLogSheet: Bool = false

    var body: some View {
        Group {
            ZStack {
                // Liquid glass background for the whole app content
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)

                VStack(spacing: 14) {
                    Text("YTScrap")
                        .font(.system(.title2, design: .monospaced))
                        .padding(.top, 12)

                    // Simple UI: user can locate a local yt-dlp binary and view logs
                    Spacer()
                }
            }
        }
        // Apply a global monospaced font design to this view hierarchy
        .font(.system(.body, design: .monospaced))
        .padding(14)
        .frame(minWidth: 520, minHeight: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(8)
                    
                    // Center loading bar overlay (appears in middle while downloading)
                    // No center loading bar — download flow removed
                    .overlay {
                        EmptyView()
                    }
                    // Separate status bar anchored to bottom of the app (always visible)
                    .overlay(alignment: .bottom) {
                        StatusBarView(vm: vm, showLog: { showLogSheet = true })
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 10)
                    }
                    .animation(.easeInOut(duration: 0.22), value: vm.status)
        // Present the in-app log viewer as a sheet from ContentView scope
        .sheet(isPresented: $showLogSheet) {
            LogViewer(vm: vm, isPresented: $showLogSheet)
        }
    }

    // locate/copy/sign workflows are handled via StatusBar and locate button

    // MARK: - Auxiliary Views

}

// Removed center loading bar — download UI removed from the app.

// MARK: - Bottom Status Bar

struct StatusBarView: View {
    @ObservedObject var vm: YTDLPViewModel
    let showLog: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left icon and compact percent
            Image(systemName: "info.circle")
                .foregroundStyle(Color.accentColor)
                .font(.system(.title3, design: .monospaced))

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.status)
                    .font(.system(.footnote, design: .monospaced)).bold()
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(vm.statusSummary)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right corner: show yt-dlp availability and version
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: vm.ytdlpAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(vm.ytdlpAvailable ? Color.green : Color.orange)
                        .font(.system(.body, design: .monospaced))
                    Text(vm.ytdlpAvailable ? "yt-dlp" : "yt-dlp")
                        .font(.system(.caption2, design: .monospaced)).bold()
                }
                Text(vm.ytdlpAvailable ? (vm.ytdlpVersion ?? "v?") : "Not installed")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(vm.ytdlpAvailable ? .secondary : .red)
            }

            // Small utilities: show the install log and allow retrying install
            HStack(spacing: 8) {
                Button(action: { showLog() }) {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Show Log")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { vm.openReleasePage() }) {
                    Image(systemName: "link")
                    Text("Open Release")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { Task { await vm.locateLocalBinary() } }) {
                    Image(systemName: "magnifyingglass")
                    Text("Locate Binary")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { vm.retryInstall() }) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Move sheet to ContentView scope; StatusBarView will call showLog closure

            // No cancel button — no download flow in-app
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.06)))
    }
}

// MARK: - Log Viewer Sheet

struct LogViewer: View {
    @ObservedObject var vm: YTDLPViewModel
    @Binding var isPresented: Bool

    @State private var logText: String = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("yt-dlp Install Log")
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            ScrollView {
                Text(logText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(.textBackgroundColor).opacity(0.02))
            .cornerRadius(8)

            HStack(spacing: 10) {
                Button(action: { refresh() }) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .buttonStyle(.bordered)

                Button(action: { copyToPasteboard() }) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: { clear() }) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: { vm.openInstallLog() }) {
                    Image(systemName: "folder")
                    Text("Open In Finder")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 320)
        .onAppear { refresh() }
    }

    private func refresh() {
        logText = vm.readInstallLog() ?? "No install log found."
    }

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(logText, forType: .string)
    }

    private func clear() {
        vm.clearInstallLog()
        refresh()
    }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
