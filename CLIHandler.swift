import Foundation
import AVFoundation
import Photos

/// CLI 模式处理器
/// 用法:
///   LivePhotoForge video1.mp4 video2.mp4              → 直接导入系统相册
///   LivePhotoForge -o ./output video1.mp4 video2.mp4   → 输出到指定目录
///   LivePhotoForge --frame-time 1.5 video.mp4          → 指定封面帧
///   LivePhotoForge -o ./out --import video.mp4          → 同时输出文件 + 导入相册
class CLIHandler {

    static func run(_ rawArgs: [String]) {
        var outputDir: String?
        var frameTime: Double = 0
        var forceImport = false
        var videoFiles: [String] = []

        // ── 解析参数 ──
        var i = 0
        while i < rawArgs.count {
            switch rawArgs[i] {
            case "-o", "--output":
                i += 1
                guard i < rawArgs.count else { die("缺少输出目录参数") }
                outputDir = rawArgs[i]
            case "--import":
                forceImport = true
            case "--frame-time":
                i += 1
                guard i < rawArgs.count, let t = Double(rawArgs[i]) else {
                    die("缺少或无效的封面帧时间参数")
                }
                frameTime = t
            case "-h", "--help":
                printUsage(); exit(0)
            default:
                if rawArgs[i].hasPrefix("-") {
                    die("未知参数: \(rawArgs[i])")
                }
                videoFiles.append(rawArgs[i])
            }
            i += 1
        }

        guard !videoFiles.isEmpty else {
            die("请提供至少一个视频文件路径")
        }

        // 未指定 -o 时，默认导入相册
        let shouldImport = forceImport || (outputDir == nil)

        // ── 异步执行 ──
        let sema = DispatchSemaphore(value: 0)
        Task {
            defer { sema.signal() }

            var successCount = 0
            var failCount = 0

            for path in videoFiles {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    .standardizedFileURL
                guard FileManager.default.fileExists(atPath: url.path) else {
                    printErr("文件不存在: \(path)")
                    failCount += 1
                    continue
                }

                let base = url.deletingPathExtension().lastPathComponent
                print("\n📹 处理: \(url.lastPathComponent)")

                do {
                    // Step 1: 提取封面帧
                    print("  [1/3] 提取封面帧 (t=\(frameTime)s)…")
                    let frameURL = try await ConversionEngine.extractFrame(from: url, at: frameTime)

                    // Step 2: 转封装为 MOV
                    print("  [2/3] 转换为 MOV 容器…")
                    let movURL = try await ConversionEngine.convertToMOV(input: url)

                    // Step 3a: 输出到目录
                    if let dir = outputDir {
                        let fm = FileManager.default
                        try fm.createDirectory(
                            atPath: dir, withIntermediateDirectories: true, attributes: nil
                        )
                        let destDir = URL(fileURLWithPath: dir)
                        let destJPG = destDir.appendingPathComponent(base + ".jpg")
                        let destMOV = destDir.appendingPathComponent(base + ".mov")

                        try? fm.removeItem(at: destJPG)
                        try? fm.removeItem(at: destMOV)
                        try fm.copyItem(at: frameURL, to: destJPG)
                        try fm.copyItem(at: movURL, to: destMOV)

                        let jpgSize = (try? fm.attributesOfItem(atPath: destJPG.path)[.size] as? Int64) ?? 0
                        let movSize = (try? fm.attributesOfItem(atPath: destMOV.path)[.size] as? Int64) ?? 0
                        print("  📁 已输出到 \(dir)/")
                        print("     \(base).jpg  (\(ByteCountFormatter.string(fromByteCount: jpgSize, countStyle: .file)))")
                        print("     \(base).mov  (\(ByteCountFormatter.string(fromByteCount: movSize, countStyle: .file)))")
                    }

                    // Step 3b: 导入系统相册
                    if shouldImport {
                        print("  [3/3] 导入系统相册…")
                        try await ConversionEngine.importToPhotos(imageURL: frameURL, videoURL: movURL)
                        print("  ✅ 已导入系统相册（iCloud 将自动同步到 iPhone）")
                    } else {
                        print("  ✅ 完成")
                    }

                    // 清理临时文件
                    try? FileManager.default.removeItem(at: frameURL)
                    try? FileManager.default.removeItem(at: movURL)

                    successCount += 1

                } catch {
                    printErr("  ❌ 失败: \(error.localizedDescription)")
                    failCount += 1
                }
            }

            // 汇总
            print("\n══════════════════════════════════")
            print("全部完成！成功 \(successCount) 个，失败 \(failCount) 个")
            if shouldImport && successCount > 0 {
                print("💡 打开「照片」App 即可查看，iCloud 同步后手机上也会出现")
            }
        }

        sema.wait()
        exit(0)
    }

    // MARK: - 帮助信息
    private static func printUsage() {
        let help = """
        
        ╔══════════════════════════════════════════════╗
        ║  LivePhotoForge — 视频转苹果实况图            ║
        ╚══════════════════════════════════════════════╝

        用法:
          LivePhotoForge [选项] <视频文件...>

        选项:
          -o, --output <目录>     输出 .jpg + .mov 文件到指定目录
          --import                导入到系统相册（不指定 -o 时为默认行为）
          --frame-time <秒>       封面帧时间点（默认 0，即第一帧）
          -h, --help              显示本帮助

        示例:
          LivePhotoForge video.mp4
              → 直接导入系统相册

          LivePhotoForge -o ~/Desktop/livephotos video1.mp4 video2.mp4
              → 批量输出到桌面

          LivePhotoForge --frame-time 2.0 clip.mp4
              → 取第 2 秒为封面帧

          LivePhotoForge -o ./out --import video.mp4
              → 同时输出文件并导入相册

        无参数启动则打开图形界面（GUI 模式）。
        """
        print(help)
    }

    private static func die(_ msg: String) -> Never {
        printErr("错误: \(msg)")
        printErr("使用 -h 查看帮助")
        exit(1)
    }

    private static func printErr(_ msg: String) {
        FileHandle.standardError.write(Data("\(msg)\n".utf8))
    }
}
