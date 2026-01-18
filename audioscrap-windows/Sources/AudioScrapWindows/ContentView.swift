#if canImport(SwiftWin32)
import SwiftWin32
#else
import SwiftUI
#endif

import Foundation

// A simplified ContentView ported to the Windows scaffold using SwiftWin32 where available.

struct ContentView: View {
    @StateObject private var downloadManager = DownloadManager()
    @State private var urlInput: String = ""
    @State private var showingAbout = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("🎵")
                        .font(.system(size: 32))
                    Text("audioscrap")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                }
                Spacer()
                Button(action: { showingSettings = true }) { Text("⚙️") }
                Button(action: { showingAbout = true }) { Text("ℹ️") }
            }
            .padding()

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save to:")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                    HStack {
                        Text(downloadManager.saveLocation)
                            .lineLimit(1)
                        Spacer()
                        Button("Change...") {
                            downloadManager.pickFolder { _ in }
                        }
                    }
                }

                TextField("Paste YouTube or SoundCloud URL here...", text: $urlInput)
                    .frame(minWidth: 400)
                Button("Clear") { urlInput = "" }
                Button("Download") {
                    let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    downloadManager.addDownload(url: trimmed)
                    urlInput = ""
                }
                .disabled(!downloadManager.isYtDlpInstalled)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(downloadManager.downloads) { item in
                        DownloadRowView(item: item, onRemove: {
                            downloadManager.removeDownload(item: item)
                        }, onShow: {
                            if let path = item.outputFile ?? item.outputPath { downloadManager.openInExplorer(path: path) }
                        })
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 420)
        .sheet(isPresented: $showingAbout) {
            VStack(spacing: 12) {
                Text("audioscrap")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                Text("Windows port - scaffold")
                Button("Close") { showingAbout = false }
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(downloadManager: downloadManager)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .monospaced))

            Form {
                Section(header: Text("Download Settings")) {
                    HStack {
                        Text("Format:")
                        Spacer()
                        Picker("Format", selection: $downloadManager.audioFormat) {
                            ForEach(downloadManager.availableAudioFormats, id: \.self) { fmt in
                                Text(fmt.uppercased()).tag(fmt)
                            }
                        }
                        .frame(width: 140)
                    }

                    HStack {
                        Text("Quality:")
                        Spacer()
                        Picker("Quality", selection: $downloadManager.audioQuality) {
                            ForEach(downloadManager.availableAudioQualityOptions.indices, id: \.self) { idx in
                                let opt = downloadManager.availableAudioQualityOptions[idx]
                                Text(opt.label).tag(opt.value)
                            }
                        }
                        .frame(width: 160)
                    }
                }
                Section(header: Text("Runtimes")) {
                    HStack {
                        Text("yt-dlp:")
                        Spacer()
                        Text(downloadManager.isYtDlpInstalled ? "Installed" : "Not found")
                    }
                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.detectYtDlp() }
                        Button("Show") { if let p = downloadManager.ytDlpPath { downloadManager.openInExplorer(path: p) } }
                        Button("Copy install") { downloadManager.copyToClipboard("winget install yt-dlp") }
                        Button("Run") { downloadManager.openPowerShellAndRun("winget install yt-dlp") }
                    }

                    HStack {
                        Text("ffmpeg:")
                        Spacer()
                        Text(downloadManager.isFfmpegInstalled ? "Installed" : "Not found")
                    }
                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.detectFfmpeg() }
                        Button("Show") { if let p = downloadManager.ffmpegPath { downloadManager.openInExplorer(path: p) } }
                        Button("Copy install") { downloadManager.copyToClipboard("winget install ffmpeg") }
                        Button("Run") { downloadManager.openPowerShellAndRun("winget install ffmpeg") }
                    }

                    HStack {
                        Text("deno:")
                        Spacer()
                        Text(downloadManager.isDenoInstalled ? "Installed" : "Not found")
                    }
                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.detectDeno() }
                        Button("Show") { if let p = downloadManager.denoPath { downloadManager.openInExplorer(path: p) } }
                        Button("Copy install") { downloadManager.copyToClipboard("winget install denoland.deno") }
                        Button("Run") { downloadManager.openPowerShellAndRun("winget install denoland.deno") }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
            }
        }
        .padding()
        .frame(width: 600, height: 420)
    }
}

struct DownloadRowView: View {
    @ObservedObject var item: DownloadItem
    let onRemove: () -> Void
    let onShow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.system(.headline, design: .monospaced))
                        .lineLimit(1)
                    Text(item.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onRemove) { Text("Remove") }
                    if item.status == .completed {
                        Button(action: onShow) { Text("Show in Explorer") }
                    }
                }
            }

            if item.status == .downloading || item.status == .processing {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
            }

            if let err = item.error, item.status == .failed {
                Text(err).foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(white: 0.95))
        .cornerRadius(8)
    }
}

#if DEBUG
struct __Preview {
    static func preview() -> some View { ContentView() }
}
#endif
