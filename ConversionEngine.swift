import Foundation
import AVFoundation
import Photos
import ImageIO
import AppKit

// MARK: - 错误类型
enum ConversionError: LocalizedError {
    case frameExtractionFailed
    case frameEncodeFailed
    case exportSessionCreationFailed
    case videoConversionFailed(String)
    case photosAccessDenied
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .frameExtractionFailed:       return "无法提取视频帧"
        case .frameEncodeFailed:           return "无法编码封面图"
        case .exportSessionCreationFailed: return "无法创建视频导出会话"
        case .videoConversionFailed(let m): return "视频转换失败：\(m)"
        case .photosAccessDenied:          return "未获得照片权限，请在系统设置中授权"
        case .importFailed(let m):         return "导入相册失败：\(m)"
        }
    }
}

// MARK: - 转换引擎
class ConversionEngine {

    // ──────── Step 1：提取封面帧 ────────
    static func extractFrame(from videoURL: URL, at seconds: Double = 0) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)

        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: cmTime)

        // 保存为高质量 JPEG
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        guard let dest = CGImageDestinationCreateWithURL(
            tmpURL as CFURL, "public.jpeg" as CFString, 1, nil
        ) else {
            throw ConversionError.frameEncodeFailed
        }
        let opts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(dest, cgImage, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.frameEncodeFailed
        }
        return tmpURL
    }

    // ──────── Step 2：转封装为 MOV（无损直拷） ────────
    static func convertToMOV(input: URL) async throws -> URL {
        let asset = AVURLAsset(url: input)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        // 优先尝试 Passthrough（直接复制流，零损耗）
        let presetName = AVAssetExportPresetPassthrough
        guard let session = AVAssetExportSession(asset: asset, presetName: presetName) else {
            throw ConversionError.exportSessionCreationFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .mov

        await session.export()

        guard session.status == .completed else {
            let msg = session.error?.localizedDescription ?? "未知错误"
            throw ConversionError.videoConversionFailed(msg)
        }
        return outputURL
    }

    // ──────── Step 3：导入系统相册（核心） ────────
    /// 使用 PHAssetCreationRequest 的 .photo + .pairedVideo 接口，
    /// 系统会自动完成 UUID 配对，生成原生 Live Photo。
    static func importToPhotos(imageURL: URL, videoURL: URL) async throws {
        // 请求权限
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ConversionError.photosAccessDenied
        }

        // 执行导入
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()

            let photoOpts = PHAssetResourceCreationOptions()
            photoOpts.shouldMoveFile = false          // 不移动源文件

            let videoOpts = PHAssetResourceCreationOptions()
            videoOpts.shouldMoveFile = false

            request.addResource(with: .photo, fileURL: imageURL, options: photoOpts)
            request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOpts)
        }
    }

    // ──────── 完整流水线 ────────
    @MainActor
    static func processVideo(_ item: VideoItem) async {
        var frameURL: URL?
        var movURL: URL?

        do {
            // 1. 提取封面帧
            item.status = .extractingFrame
            frameURL = try await extractFrame(from: item.url)

            // 2. 无损转封装为 MOV
            item.status = .convertingVideo
            movURL = try await convertToMOV(input: item.url)

            // 3. 导入系统相册
            item.status = .importingPhotos
            try await importToPhotos(imageURL: frameURL!, videoURL: movURL!)

            item.status = .completed

        } catch {
            item.status = .failed(error.localizedDescription)
        }

        // 清理临时文件
        if let f = frameURL { try? FileManager.default.removeItem(at: f) }
        if let m = movURL   { try? FileManager.default.removeItem(at: m) }
    }

    // ──────── 批量处理 ────────
    @MainActor
    static func processBatch(_ items: [VideoItem]) async {
        for item in items where item.status == .pending {
            await processVideo(item)
        }
    }
}
