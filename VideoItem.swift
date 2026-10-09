import Foundation
import AVFoundation
import AppKit

// MARK: - 转换状态
enum ConversionStatus: Equatable {
    case pending
    case extractingFrame
    case convertingVideo
    case importingPhotos
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .pending:            return "等待中"
        case .extractingFrame:    return "提取封面帧…"
        case .convertingVideo:    return "转换视频…"
        case .importingPhotos:    return "导入相册…"
        case .completed:          return "已导入相册"
        case .failed(let msg):    return msg
        }
    }

    var icon: String {
        switch self {
        case .pending:         return "clock"
        case .extractingFrame: return "photo.on.rectangle"
        case .convertingVideo: return "film"
        case .importingPhotos: return "square.and.arrow.down"
        case .completed:       return "checkmark.circle.fill"
        case .failed:          return "xmark.circle.fill"
        }
    }

    var isWorking: Bool {
        switch self {
        case .extractingFrame, .convertingVideo, .importingPhotos: return true
        default: return false
        }
    }
}

// MARK: - 视频条目模型
class VideoItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL

    @Published var status: ConversionStatus = .pending
    @Published var thumbnail: NSImage?

    // 元信息
    let filename: String
    var duration: Double = 0
    var resolution: String = "—"
    var fileSize: String = "—"

    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        loadMetadata()
    }

    // MARK: 读取视频基本信息
    private func loadMetadata() {
        // 文件大小
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let bytes = attrs[.size] as? Int64 {
            fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        // 时长 & 分辨率 & 缩略图
        let asset = AVURLAsset(url: url)
        Task {
            if let dur = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(dur)
                await MainActor.run { self.duration = secs }
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size = size, let transform = transform {
                    let applied = size.applying(transform)
                    let w = Int(abs(applied.width))
                    let h = Int(abs(applied.height))
                    await MainActor.run { self.resolution = "\(w)×\(h)" }
                }
            }

            // 生成缩略图
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 160, height: 160)
            if let (cgImg, _) = try? await gen.image(at: .zero) {
                let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
                await MainActor.run { self.thumbnail = nsImg }
            }
        }
    }

    var durationText: String {
        guard duration > 0 else { return "—" }
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        let ms = Int((duration - Double(Int(duration))) * 10)
        return m > 0 ? String(format: "%d:%02d.%d", m, s, ms) : String(format: "%d.%ds", s, ms)
    }
}
