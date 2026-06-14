//
//  DownloadItem.swift
//  audioscrap
//
//  Created by Thomas Boom on 12/8/25.
//

import Foundation
import Combine

enum DownloadStatus: String {
    case pending = "Pending"
    case downloading = "Downloading"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
}

enum Platform: String, CaseIterable {
    case youtube = "YouTube"
    case soundcloud = "SoundCloud"
    case auto = "Auto-detect"
    
    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .soundcloud: return "waveform"
        case .auto: return "link"
        }
    }
}

enum DownloadOutputKind: String, CaseIterable, Hashable {
    case audio = "Audio"
    case mov = ".mov video"
    case mp4 = ".mp4 video"

    var isVideo: Bool {
        self == .mov || self == .mp4
    }
}

class DownloadItem: Identifiable, ObservableObject {
    let id = UUID()
    @Published var url: String
    @Published var title: String
    @Published var status: DownloadStatus
    @Published var progress: Double
    @Published var platform: Platform
    @Published var outputKind: DownloadOutputKind
    @Published var error: String?
    @Published var outputPath: String?
    @Published var outputFile: String?
    @Published var metadata: [String: String] = [:]
    
    init(url: String, platform: Platform = .auto, outputKind: DownloadOutputKind = .audio) {
        self.url = url
        self.title = "Fetching info..."
        self.status = .pending
        self.progress = 0.0
        self.platform = platform
        self.outputKind = outputKind
    }
}
