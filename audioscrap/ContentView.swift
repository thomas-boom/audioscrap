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
    @State private var selectedOutputKind: DownloadOutputKind = .audio
    @State private var showingInstallWizard: Bool = false
    @State private var showingSettings = false
    @State private var bottomSettingsTab: BottomSettingsBar.Tab = .settings
    // platform picker removed; we always autodetect
    @State private var showingFolderPicker = false
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
                .font(.custom(FontManager.preferredFontPostScriptName, size: NSFont.systemFontSize))
            }

            // Bottom status bar remains visible
            statusBar
        }
        .frame(minWidth: 700, minHeight: 420)
        .onAppear {
            // Ensure the app is activated and window is brought to front
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if !UserDefaults.standard.bool(forKey: "hasSeenInstallWizard") {
                    showingInstallWizard = true
                }
            }
        }
        
        .sheet(isPresented: $showingInstallWizard) {
            InstallWizardView(downloadManager: downloadManager, isPresented: $showingInstallWizard)
        }
        .overlay(
            Group {
                if showingSettings {
                    BottomSettingsBar(downloadManager: downloadManager, isPresented: $showingSettings, selectedTab: $bottomSettingsTab)
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            },
            alignment: .bottom
        )
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
        .onChange(of: urlInput) { newValue in
            if !isYouTubeURL(newValue) {
                selectedOutputKind = .audio
            }
        }
    }

    private func isSupportedURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return false }
        if host.contains("youtube.com") || host == "youtu.be" { return true }
        if host.contains("soundcloud.com") { return true }
        return false
    }

    private func isYouTubeURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host == "youtu.be"
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        // Compute runtime availability before building the view to avoid ViewBuilder type inference issues
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
                    .font(.appFont(.caption2))
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

        return HStack(spacing: 12) {
            // About button at the left opens the bottom About tab
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)) {
                    bottomSettingsTab = .about
                    showingSettings = true
                }
            }) {
                Image(systemName: "info.circle")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .help("About")

            Spacer()

            // Center: compact runtime indicators
            HStack(spacing: 18) {
                let ytOk = ytFound && ytExecutable && ytReady
                HStack(spacing: 8) {
                    Text("yt-dlp")
                        .font(.appFont(.caption2))
                    Image(systemName: ytOk ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(ytOk ? .green : .gray)
                }

                let denoOk = denoFound && denoExecutable && denoReady
                HStack(spacing: 8) {
                    Text("deno")
                        .font(.appFont(.caption2))
                    Image(systemName: denoOk ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(denoOk ? .green : .gray)
                }

                let ffOk = ffFound && ffExecutable && ffReady
                HStack(spacing: 8) {
                    Text("ffmpeg")
                        .font(.appFont(.caption2))
                    Image(systemName: ffOk ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(ffOk ? .green : .gray)
                }
            }

            Spacer()

            // Settings button on the right
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)) {
                    bottomSettingsTab = .settings
                    showingSettings = true
                }
            }) {
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
                Image("Logo")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Audioscrap")
                        .font(.appFont(.title3))
                        .fontWeight(.bold)

                    Text("Audio and Video downloader for YouTube, SoundCloud, and more")
                        .font(.appFont(.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // Bottom tab bar removed — dependency indicators moved into Settings window.
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // Save Location
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                        Text("Save to:")
                            .font(.appFont(.caption))
                        .foregroundColor(.secondary)
                    Text(downloadManager.saveLocation)
                        .font(.appFont(.caption))
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.appFont(.title2))
                        .foregroundColor(.accentColor)
                    
                    TextField("Paste videolink (YouTube, Vimeo, etc.) or audiolink (SoundCloud, etc.) here...", text: $urlInput)
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
                            .font(.appFont(.headline))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isSupportedURL(urlInput) || !downloadManager.isYtDlpInstalled)
                }

                if isYouTubeURL(urlInput) {
                    HStack(spacing: 12) {
                        Text("Output:")
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedOutputKind) {
                            Text("Audio").tag(DownloadOutputKind.audio)
                            Text(".mov video").tag(DownloadOutputKind.mov)
                            Text(".mp4 video").tag(DownloadOutputKind.mp4)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        .help("Video requires a YouTube link and ffmpeg")

                        Spacer()
                    }
                }
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
                .font(.appFont(size: 64))
                .foregroundColor(.secondary)

            Text("No downloads yet")
                .font(.appFont(.title2))
                .fontWeight(.semibold)

            Text("Paste a YouTube or SoundCloud URL above and click Download to start")
                .font(.appFont(.body))
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

        let outputKind = isYouTubeURL(trimmedURL) ? selectedOutputKind : .audio
        downloadManager.addDownload(url: trimmedURL, outputKind: outputKind)
        urlInput = ""
        selectedOutputKind = .audio
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
                        .font(.appFont(.headline))
                        .lineLimit(1)
                    
                    Text(item.url)
                        .font(.appFont(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Live metadata (ID3-like) display
                    VStack(alignment: .leading, spacing: 2) {
                        if let artist = item.metadata["artist"] {
                            Text("Artist: \(artist)")
                                .font(.appFont(.caption2))
                                .foregroundColor(.secondary)
                        }
                        if let album = item.metadata["album"] {
                            Text("Album: \(album)")
                                .font(.appFont(.caption2))
                                .foregroundColor(.secondary)
                        }
                        if let duration = item.metadata["duration"] {
                            Text("Duration: \(duration)")
                                .font(.appFont(.caption2))
                                .foregroundColor(.secondary)
                        }
                    }
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
                            .font(.appFont(.caption2))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(item.progress * 100))%")
                            .font(.appFont(.caption2))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Error message
            if let error = item.error, item.status == .failed {
                Text(error)
                    .font(.appFont(.caption))
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
                        .font(.appFont(.caption))
                        .foregroundColor(.secondary)
                    
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: outputPath)
                    }
                    .buttonStyle(.link)
                    .font(.appFont(.caption))
                }
            }
        }
        .font(.appFont(.body))
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
        .font(.appFont(.title3))
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
    // Optional binding used when SettingsView is embedded in the bottom overlay.
    // If nil, fall back to `dismiss()` for modal presentations.
    var isPresented: Binding<Bool>? = nil
    var onRequestDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.appFont(.title))
                .fontWeight(.bold)
            
            // Make the default font inside settings monospaced
            
            
            Form {
                Section("Download Settings") {
                    HStack {
                        Text("Audio Quality:")
                        Spacer()
                        if downloadManager.audioFormat == "flac" {
                            // Show a static label for FLAC to avoid confusion
                            Text("Best (0)")
                                .font(.appFont(.caption))
                                .foregroundColor(.secondary)
                                .frame(width: 160, alignment: .trailing)
                                .help("FLAC uses the best available quality")
                        } else {
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
                    }
                    
                    HStack {
                        Text("Format:")
                        Spacer()
                        // Picker for available audio formats (MP3, FLAC)
                        Picker("Format", selection: $downloadManager.audioFormat) {
                            ForEach(downloadManager.availableAudioFormats, id: \.self) { fmt in
                                Text(fmt.uppercased()).tag(fmt)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .help("Select output format. Quality options disabled for FLAC")
                    }

                    HStack {
                        Text("Video Quality:")
                        Spacer()
                        Picker("Video Quality", selection: $downloadManager.videoQuality) {
                            ForEach(downloadManager.availableVideoQualityOptions.indices, id: \.self) { idx in
                                let opt = downloadManager.availableVideoQualityOptions[idx]
                                Text(opt.label).tag(opt.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                        .help("Used when MP4 video is selected")
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
                                .font(.appFont(.caption))
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
                                .font(.appFont(.caption))
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
                                .font(.appFont(.caption))
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
                if let onRequestDismiss = onRequestDismiss {
                    onRequestDismiss()
                } else if let isPresented = isPresented {
                    isPresented.wrappedValue = false
                } else {
                    dismiss()
                }
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
