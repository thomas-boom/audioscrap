//
//  InstallWizardView.swift
//  audioscrap

import SwiftUI
import AppKit

struct InstallWizardView: View {
    @ObservedObject var downloadManager: DownloadManager
    @Binding var isPresented: Bool
    @State private var installingAll: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Setup dependencies")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("AudioScrap needs yt-dlp, deno and ffmpeg. This wizard can install them via Homebrew if available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Homebrew
                HStack {
                    Text("Homebrew")
                    Spacer()
                    if downloadManager.isBrewAvailable {
                        Label("Installed", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    } else {
                        Label("Not Found", systemImage: "xmark.circle.fill").foregroundColor(.red)
                    }
                }
                if !downloadManager.isBrewAvailable {
                    HStack(spacing: 8) {
                        Button("Open Homebrew site") { downloadManager.openHomebrewSite() }
                        Button("Copy install command") { downloadManager.copyHomebrewInstallCommandToClipboard() }
                    }
                }

                Group {
                    HStack {
                        Text("yt-dlp")
                        Spacer()
                        statusView(installed: downloadManager.isYtDlpInstalled)
                    }
                    HStack {
                        if downloadManager.isYtDlpInstalled {
                            Text("Ready").foregroundColor(.secondary)
                        } else if downloadManager.isBrewAvailable {
                            Button("Install yt-dlp") { downloadManager.installYtDlpViaBrew() }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("yt-dlp instructions") { if let url = URL(string: "https://github.com/yt-dlp/yt-dlp") { NSWorkspace.shared.open(url) } }
                        }
                    }

                    HStack {
                        Text("deno")
                        Spacer()
                        statusView(installed: downloadManager.isDenoInstalled)
                    }
                    HStack {
                        if downloadManager.isDenoInstalled {
                            Text("Ready").foregroundColor(.secondary)
                        } else if downloadManager.isBrewAvailable {
                            Button("Install deno") { downloadManager.installDenoViaBrew() }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("deno instructions") { if let url = URL(string: "https://deno.land/#installation") { NSWorkspace.shared.open(url) } }
                        }
                    }

                    HStack {
                        Text("ffmpeg")
                        Spacer()
                        statusView(installed: downloadManager.isFfmpegInstalled)
                    }
                    HStack {
                        if downloadManager.isFfmpegInstalled {
                            Text("Ready").foregroundColor(.secondary)
                        } else if downloadManager.isBrewAvailable {
                            Button("Install ffmpeg") { downloadManager.installFfmpegViaBrew() }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button("ffmpeg instructions") { if let url = URL(string: "https://ffmpeg.org/download.html") { NSWorkspace.shared.open(url) } }
                        }
                    }
                }
            }

            Divider()

            HStack {
                if downloadManager.isBrewAvailable {
                    Button(action: {
                        installingAll = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            downloadManager.installAllDependencies() {
                                DispatchQueue.main.async {
                                    installingAll = false
                                    // force re-checks
                                    downloadManager.checkYtDlpInstallation(brewPrefix: downloadManager.brewPrefix)
                                    downloadManager.checkDenoInstallation(brewPrefix: downloadManager.brewPrefix)
                                    downloadManager.checkFfmpegInstallation(brewPrefix: downloadManager.brewPrefix)
                                }
                            }
                        }
                    }) {
                        Text(installingAll ? "Installing..." : "Install All")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                Button("Skip") {
                    UserDefaults.standard.set(true, forKey: "hasSeenInstallWizard")
                    isPresented = false
                }

                Button("Done") {
                    UserDefaults.standard.set(true, forKey: "hasSeenInstallWizard")
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 560)
    }

    @ViewBuilder
    private func statusView(installed: Bool) -> some View {
        if installed {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else {
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        }
    }
}

struct InstallWizardView_Previews: PreviewProvider {
    static var previews: some View {
        InstallWizardView(downloadManager: DownloadManager(), isPresented: .constant(true))
    }
}
