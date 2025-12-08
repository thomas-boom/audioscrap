//
//  ContentView.swift
//  audioscrap
//
//  Created by Thomas Boom on 12/7/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var downloadManager = DownloadManager()
    @State private var urlInput: String = ""
    // platform picker removed; we always autodetect
    @State private var showingSettings = false
    @State private var showingFolderPicker = false
    @State private var showingAbout = false
    @State private var showingInvalidAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content area (all UI elements live here)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerView
                    inputSection

                    Divider()

                    if downloadManager.downloads.isEmpty {
                        emptyStateView
                    } else {
                        downloadsListView
                    }
                }
                .padding()
                .font(.system(.body, design: .monospaced))
            }

            // Bottom status bar remains visible
            Divider()
            statusBar
        }
        .frame(minWidth: 700, minHeight: 420)
        .onAppear {
            // Ensure the app is activated and window is brought to front
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(downloadManager: downloadManager)
        }
        .sheet(isPresented: $showingAbout) {
            aboutSheet
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    downloadManager.saveLocation = url.path
                }
            case .failure(let error):
                print("Error selecting folder: \(error.localizedDescription)")
            }
        }
        .alert(isPresented: $showingInvalidAlert) {
            Alert(title: Text("Unsupported URL"), message: Text("Please paste a YouTube or SoundCloud URL only."), dismissButton: .default(Text("OK")))
        }
    }

    private func isSupportedURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return false }
        if host.contains("youtube.com") || host == "youtu.be" { return true }
        if host.contains("soundcloud.com") { return true }
        return false
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        // Compute runtime availability before building the view to avoid ViewBuilder type inference issues
        // yt-dlp checks
        let ytFound = !downloadManager.ytDlpPath.isEmpty || downloadManager.ytDlpCandidatePath != nil || downloadManager.ytDlpResolvedCandidatePath != nil
        let ytExecutable = (!downloadManager.ytDlpPath.isEmpty && FileManager.default.isExecutableFile(atPath: downloadManager.ytDlpPath)) || (downloadManager.ytDlpResolvedCandidatePath != nil && FileManager.default.isExecutableFile(atPath: downloadManager.ytDlpResolvedCandidatePath!))
        let ytReady = downloadManager.isYtDlpInstalled

        // deno checks
        let denoFound = !downloadManager.denoPath.isEmpty || downloadManager.denoCandidatePath != nil || downloadManager.denoResolvedCandidatePath != nil
        let denoExecutable = (!downloadManager.denoPath.isEmpty && FileManager.default.isExecutableFile(atPath: downloadManager.denoPath)) || (downloadManager.denoResolvedCandidatePath != nil && FileManager.default.isExecutableFile(atPath: downloadManager.denoResolvedCandidatePath!))
        let denoReady = downloadManager.isDenoInstalled

        // ffmpeg checks
        let ffFound = !downloadManager.ffmpegPath.isEmpty || downloadManager.ffmpegCandidatePath != nil || downloadManager.ffmpegResolvedCandidatePath != nil
        let ffExecutable = (!downloadManager.ffmpegPath.isEmpty && FileManager.default.isExecutableFile(atPath: downloadManager.ffmpegPath)) || (downloadManager.ffmpegResolvedCandidatePath != nil && FileManager.default.isExecutableFile(atPath: downloadManager.ffmpegResolvedCandidatePath!))
        let ffReady = downloadManager.isFfmpegInstalled

        // Helper to render three-state checks for a runtime
        func runtimeChecks(name: String, found: Bool, executable: Bool, ready: Bool) -> some View {
            HStack(spacing: 6) {
                Text(name)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(minWidth: 54, alignment: .leading)

                Image(systemName: executable ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(executable ? .green : .gray)
                    .help("Executable")

                Image(systemName: found ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(found ? .green : .gray)
                    .help("Found")

                Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ready ? .green : .gray)
                    .help("Ready")
            }
        }

        return HStack(spacing: 24) {
            // Single combined check per runtime: present && executable && reported ready
            let ytOk = ytFound && ytExecutable && ytReady
            HStack(spacing: 8) {
                Text("yt-dlp")
                    .font(.system(.caption2, design: .monospaced))
                Image(systemName: ytOk ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ytOk ? .green : .gray)
            }

            let denoOk = denoFound && denoExecutable && denoReady
            HStack(spacing: 8) {
                Text("deno")
                    .font(.system(.caption2, design: .monospaced))
                Image(systemName: denoOk ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(denoOk ? .green : .gray)
            }

            let ffOk = ffFound && ffExecutable && ffReady
            HStack(spacing: 8) {
                Text("ffmpeg")
                    .font(.system(.caption2, design: .monospaced))
                Image(systemName: ffOk ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ffOk ? .green : .gray)
            }

            Spacer()

            // Settings button kept small
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.vertical, 6)
        .padding(.horizontal)
        // Use Apple's liquid glass (ultraThinMaterial) for a native translucent status bar
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12)))
        .padding([.horizontal, .bottom])
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("audioscrap")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                Spacer()

                // About / Info button on the right side of the title
                Button(action: { showingAbout = true }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help("About this app")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // About sheet content (moved from Settings -> About)
    private var aboutSheet: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "audioscrap"
                    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
                    Text(appName)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                    Text("Version \(shortVersion) (\(build))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AudioScrap is front-end that uses yt-dlp to download the highest quality audio available from YouTube and SoundCloud, converting it to MP3 format with metadata and album art.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)

                    // Additional app details (smaller text)
                    Group {
                        HStack {
                            Text("Author:")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Thomas Boom")
                                .font(.system(.caption2, design: .monospaced))
                        }

                        HStack {
                            Text("Repository:")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("View on GitHub") {
                                if let url = URL(string: "https://github.com/thomas-boom/audioscrap") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }

                        HStack {
                            Text("Support:")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Report an issue") {
                                if let url = URL(string: "https://github.com/thomas-boom/audioscrap/issues") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.top, 6)

                }
                .padding(.bottom)
            }

            HStack {
                Spacer()
                Button("Done") { showingAbout = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 260)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // Save Location
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to:")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(downloadManager.saveLocation)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Change...") {
                    showingFolderPicker = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Platform selection removed — autodetect only
            
            // URL Input
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.accentColor)
                
                TextField("Paste YouTube or SoundCloud URL here...", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addDownload()
                    }
                Button(action: { urlInput = "" }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Clear URL")
                .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                
                Button(action: {
                    let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
                    guard isSupportedURL(trimmed) else {
                        showingInvalidAlert = true
                        return
                    }
                    addDownload()
                }) {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.system(.headline, design: .monospaced))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isSupportedURL(urlInput) || !downloadManager.isYtDlpInstalled)
            }
                .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No downloads yet")
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)

            Text("Paste a YouTube or SoundCloud URL above and click Download to start")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // yt-dlp installation information moved to the bottom status bar

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .center)
    }
    
    // MARK: - Downloads List
    private var downloadsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(downloadManager.downloads) { item in
                    DownloadRowView(item: item, onRemove: {
                        withAnimation(.easeInOut) {
                            downloadManager.removeDownload(item: item)
                        }
                    })
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.8), value: downloadManager.downloads.count)
            }
                        Divider()
            .padding()
        }
    }
    
    // MARK: - Actions
    private func addDownload() {
        let trimmedURL = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmedURL.isEmpty else { return }
        
        downloadManager.addDownload(url: trimmedURL)
        urlInput = ""
    }
}

// MARK: - Download Row View
struct DownloadRowView: View {
    @ObservedObject var item: DownloadItem
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status Icon
                statusIcon
                
                // Title and URL
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(.headline, design: .monospaced))
                        .lineLimit(1)
                    
                    Text(item.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            
            // Progress Bar
            if item.status == .downloading || item.status == .processing {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: item.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .animation(.linear(duration: 0.12), value: item.progress)
                    
                    HStack {
                        Text(item.status.rawValue)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(item.progress * 100))%")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Error message
            if let error = item.error, item.status == .failed {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Success message
            if item.status == .completed, let outputPath = item.outputPath {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Saved to Downloads")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: outputPath)
                    }
                    .buttonStyle(.link)
                    .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var statusIcon: some View {
        Group {
            switch item.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case .downloading:
                ProgressView()
                    .scaleEffect(0.7)
            case .processing:
                ProgressView()
                    .scaleEffect(0.7)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.system(.title3, design: .monospaced))
        .frame(width: 30)
        .scaleEffect(item.status == .downloading ? 1.07 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: item.status)
    }
    
    private var borderColor: Color {
        switch item.status {
        case .completed:
            return .green.opacity(0.3)
        case .failed:
            return .red.opacity(0.3)
        case .downloading, .processing:
            return .blue.opacity(0.3)
        default:
            return .gray.opacity(0.2)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.system(.title, design: .monospaced))
                .fontWeight(.bold)
            
            // Make the default font inside settings monospaced
            
            
            Form {
                Section("Download Settings") {
                    HStack {
                        Text("Audio Quality:")
                        Spacer()
                        Picker("Quality", selection: $downloadManager.audioQuality) {
                            ForEach(downloadManager.availableAudioQualityOptions.indices, id: \.self) { idx in
                                let opt = downloadManager.availableAudioQualityOptions[idx]
                                Text(opt.label).tag(opt.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .help("0 = best (variable), or use e.g. 320k for a target bitrate")
                    }
                    
                    HStack {
                        Text("Format:")
                        Spacer()
                        // Static label since only MP3 is supported
                        Text("MP3")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 140, alignment: .trailing)
                            .help("Format is fixed to MP3 (bitrate options only apply to MP3)")
                    }
                }
                
                Section("Deno Runtime") {
                    HStack {
                        Text("Status:")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(downloadManager.isDenoInstalled ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(downloadManager.isDenoInstalled ? "Installed" : "Not Found")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if downloadManager.isDenoInstalled {
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text(downloadManager.denoPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Actions mirroring yt-dlp remediation
                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.checkDenoInstallation() }
                            .buttonStyle(.bordered)
                        
                        Button("Show") { downloadManager.openDenoInFinder() }
                            .buttonStyle(.bordered)
                        
                        Button("Make Executable") { downloadManager.makeDenoExecutable() }
                            .buttonStyle(.borderedProminent)
                        
                        Button("Run in Terminal") { downloadManager.openTerminalAndRunDenoChmod() }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 8) {
                        Button("Copy chmod") { downloadManager.copyDenoChmodCommandToClipboard() }
                            .buttonStyle(.bordered)
                        
                        Button("Install via Brew") { downloadManager.installDenoViaBrew() }
                            .buttonStyle(.borderedProminent)
                        
                        Button("Copy brew cmd") { downloadManager.copyDenoBrewCommandToClipboard() }
                            .buttonStyle(.bordered)
                    }
                }

                Section("yt-dlp Runtime") {
                    HStack {
                        Text("Status:")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(downloadManager.isYtDlpInstalled ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(downloadManager.isYtDlpInstalled ? "Installed" : "Not Found")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if downloadManager.isYtDlpInstalled {
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text(downloadManager.ytDlpPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.checkYtDlpInstallation() }
                            .buttonStyle(.bordered)
                        
                        Button("Show") { downloadManager.openYtDlpInFinder() }
                            .buttonStyle(.bordered)
                        
                        Button("Make Executable") { downloadManager.makeYtDlpExecutable() }
                            .buttonStyle(.borderedProminent)
                        
                        Button("Run in Terminal") { downloadManager.openTerminalAndRunChmod() }
                            .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 8) {
                        Button("Copy chmod") { downloadManager.copyChmodCommandToClipboard() }
                            .buttonStyle(.bordered)
                        
                        Button("Install via Brew") { downloadManager.installYtDlpViaBrew() }
                            .buttonStyle(.borderedProminent)
                        
                        Button("Copy brew cmd") { downloadManager.copyBrewCommandToClipboard() }
                            .buttonStyle(.bordered)
                    }
                    
                    // Test notification removed per UI request
                }

                Section("ffmpeg Runtime") {
                    HStack {
                        Text("Status:")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(downloadManager.isFfmpegInstalled ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(downloadManager.isFfmpegInstalled ? "Installed" : "Not Found")
                                .foregroundColor(.secondary)
                        }
                    }

                    if downloadManager.isFfmpegInstalled {
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text(downloadManager.ffmpegPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("Recheck") { downloadManager.checkFfmpegInstallation() }
                            .buttonStyle(.bordered)

                        Button("Show") { downloadManager.openFfmpegInFinder() }
                            .buttonStyle(.bordered)

                        Button("Make Executable") { downloadManager.makeFfmpegExecutable() }
                            .buttonStyle(.borderedProminent)

                        Button("Run in Terminal") { downloadManager.openTerminalAndRunFfmpegChmod() }
                            .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        Button("Copy chmod") { downloadManager.copyFfmpegChmodCommandToClipboard() }
                            .buttonStyle(.bordered)

                        Button("Install via Brew") { downloadManager.installFfmpegViaBrew() }
                            .buttonStyle(.borderedProminent)

                        Button("Copy brew cmd") { downloadManager.copyFfmpegBrewCommandToClipboard() }
                            .buttonStyle(.bordered)
                    }
                }
                
                // About moved to header info button
            }
            .formStyle(.grouped)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

#Preview {
    ContentView()
}
