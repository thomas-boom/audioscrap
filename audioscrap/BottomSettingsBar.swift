//
//  BottomSettingsBar.swift
//  audioscrap
//
//

import SwiftUI
import AppKit

// Shape that rounds only the top corners
struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct BottomSettingsBar: View {
    @ObservedObject var downloadManager: DownloadManager
    @Binding var isPresented: Bool
    @Binding var selectedTab: Tab

    @State private var floatBubbles = false
    @State private var isVisible = false

    enum Tab: Int, CaseIterable {
        case settings
        case about
    }

    var body: some View {
        ZStack {
            // Decorative floating blobs to suggest a liquid feel
            GeometryReader { geo in
                Circle()
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 220, height: 220)
                    .blur(radius: 34)
                    .offset(x: floatBubbles ? -60 : -120, y: -40)
                    .blendMode(.plusLighter)

                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.10), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 160, height: 160)
                    .blur(radius: 26)
                    .offset(x: floatBubbles ? 80 : 120, y: -20)
                    .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.primary.opacity(0.16))
                    .frame(width: 56, height: 6)
                    .padding(.top, 8)

                HStack(spacing: 12) {
                    // About icon in the left corner
                    Button(action: { withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82)) { selectedTab = .about } }) {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)

                    Spacer()

                    // Center: compact dependency badges
                    HStack(spacing: 12) {
                        runtimeBadge(name: "yt-dlp", installed: downloadManager.isYtDlpInstalled, path: downloadManager.ytDlpPath, action: { downloadManager.openYtDlpInFinder() })
                        runtimeBadge(name: "deno", installed: downloadManager.isDenoInstalled, path: downloadManager.denoPath, action: { downloadManager.openDenoInFinder() })
                        runtimeBadge(name: "ffmpeg", installed: downloadManager.isFfmpegInstalled, path: downloadManager.ffmpegPath, action: { downloadManager.openFfmpegInFinder() })
                    }

                    Spacer()

                    // Settings button on the right
                    Button(action: { withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82)) { selectedTab = .settings } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape").imageScale(.medium)
                            Text("Settings").font(.appFont(.subheadline))
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { dismissWithAnimation() }) {
                        Text("Done")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 8)

                Divider()

                if selectedTab == .settings {
                    SettingsView(downloadManager: downloadManager, isPresented: $isPresented, onRequestDismiss: { dismissWithAnimation() })
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                } else {
                    AboutContent(downloadManager: downloadManager)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .background(.ultraThinMaterial)
            .clipShape(TopRoundedRectangle(cornerRadius: 18))
            .overlay(TopRoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.12)))
            .shadow(color: Color.black.opacity(0.12), radius: 40, x: 0, y: -10)
        }
        .frame(height: 340)
        .offset(y: isVisible ? 0 : 36)
        .opacity(isVisible ? 1 : 0)
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.82), value: isVisible)
        .onAppear {
            floatBubbles = true
            withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.82)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
        }
    }

        @ViewBuilder
        private func runtimeBadge(name: String, installed: Bool, path: String, action: @escaping ()->Void) -> some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(installed ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.appFont(.caption2))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help(path.isEmpty ? "Not installed" : "Path: \(path)")
        }
}

// Compact settings content used inside the bottom bar — mirrors the most relevant controls
struct BottomSettingsContent: View {
    @ObservedObject var downloadManager: DownloadManager
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    HStack {
                        Text("Download Settings")
                            .font(.appFont(.caption))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack {
                        Text("Format:")
                        Spacer()
                        Text(downloadManager.audioFormat.uppercased())
                            .font(.appFont(.caption))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Group {
                    Text("Runtimes")
                        .font(.appFont(.caption))
                        .foregroundColor(.secondary)

                    runtimeRow(name: "yt-dlp", installed: downloadManager.isYtDlpInstalled, path: downloadManager.ytDlpPath, action1: { downloadManager.checkYtDlpInstallation() }, action2: { downloadManager.openYtDlpInFinder() })

                    runtimeRow(name: "deno", installed: downloadManager.isDenoInstalled, path: downloadManager.denoPath, action1: { downloadManager.checkDenoInstallation() }, action2: { downloadManager.openDenoInFinder() })

                    runtimeRow(name: "ffmpeg", installed: downloadManager.isFfmpegInstalled, path: downloadManager.ffmpegPath, action1: { downloadManager.checkFfmpegInstallation() }, action2: { downloadManager.openFfmpegInFinder() })
                }
            }
        }
    }

    @ViewBuilder
    private func runtimeRow(name: String, installed: Bool, path: String, action1: @escaping ()->Void, action2: @escaping ()->Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.appFont(.body))
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(installed ? Color.green : Color.red).frame(width: 8, height: 8)
                    Text(installed ? "Installed" : "Not Found")
                        .foregroundColor(.secondary)
                }
            }

            if !path.isEmpty {
                Text(path)
                    .font(.appFont(.caption2))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button("Recheck", action: action1).buttonStyle(.bordered)
                Button("Show", action: action2).buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }
}

struct BottomSettingsBar_Previews: PreviewProvider {
    static var previews: some View {
        // Use ContentView preview to provide a DownloadManager
        ContentView()
            .previewLayout(.sizeThatFits)
    }
}

// About content reused inside the bottom settings bar
struct AboutContent: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var showingSupported = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "audioscrap"
                    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
                    Text(appName)
                        .font(.appFont(.title))
                        .fontWeight(.bold)
                    Text("Version \(shortVersion) (\(build))")
                        .font(.appFont(.caption))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AudioScrap is front-end that uses yt-dlp to download the highest quality audio available from YouTube and SoundCloud, converting it to MP3 format with metadata and album art.")
                        .font(.appFont(.footnote))
                        .foregroundColor(.secondary)

                    Group {
                        HStack {
                            Text("Author:")
                                        .font(.appFont(.caption2))
                                        .foregroundColor(.secondary)
                            Spacer()
                            Text("Thomas Boom")
                                .font(.appFont(.caption2))
                        }

                        HStack {
                            Text("Repository:")
                                .font(.appFont(.caption2))
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
                                .font(.appFont(.caption2))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Report an issue") {
                                if let url = URL(string: "https://github.com/thomas-boom/audioscrap/issues") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }

                        HStack {
                            Text("Supported Links:")
                                .font(.appFont(.caption2))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("View") {
                                showingSupported = true
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.top, 4)

                }
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingSupported) {
            SupportedLinksView(downloadManager: downloadManager)
        }
    }
}

// View that queries yt-dlp for supported extractors (if available) and shows them
struct SupportedLinksView: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) var dismiss
    @State private var sites: [String] = []
    @State private var loading = false
    @State private var errorMsg: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Supported Links")
                    .font(.appFont(.title2))
                    .fontWeight(.semibold)
                Spacer()
                Button("Close") { dismiss() }
            }
            Divider()

            if loading {
                ProgressView("Loading...")
                    .padding()
            } else if !sites.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(sites, id: \.self) { s in
                            Text(s)
                                .font(.appFont(.caption2))
                                .lineLimit(1)
                                .contextMenu {
                                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string) }
                                }
                        }
                    }
                    .padding()
                }
            } else if let e = errorMsg {
                VStack(spacing: 8) {
                    Text(e)
                        .font(.appFont(.body))
                        .foregroundColor(.secondary)
                    HStack {
                        if downloadManager.isYtDlpInstalled || !downloadManager.ytDlpPath.isEmpty {
                            Button("Retry") { fetch() }
                        } else {
                            Button("Open online list") {
                                if let url = URL(string: "https://github.com/yt-dlp/yt-dlp/blob/master/docs/supportedsites.md") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Text("No supported links found.")
                        .font(.appFont(.body))
                        .foregroundColor(.secondary)
                    Button("Load") { fetch() }
                }
                .padding()
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { fetch() }
    }

    private func fetch() {
        loading = true
        errorMsg = nil
        sites = []
        downloadManager.listSupportedSites { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let arr):
                    sites = arr.sorted()
                case .failure(let err):
                    errorMsg = "Failed to load supported links: \(err.localizedDescription)"
                }
            }
        }
    }
}
