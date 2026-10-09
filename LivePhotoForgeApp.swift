import SwiftUI
import Photos

// 不使用 @main —— 入口由 main.swift 控制（支持 CLI / GUI 双模式）
struct LivePhotoForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, minHeight: 460)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 520)
    }
}

// MARK: - AppDelegate（处理 Dock 图标拖拽）
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
        let videoURLs = urls.filter { videoExts.contains($0.pathExtension.lowercased()) }
        guard !videoURLs.isEmpty else { return }
        NotificationCenter.default.post(name: .addVideosFromDock, object: videoURLs)
    }
}

extension Notification.Name {
    static let addVideosFromDock = Notification.Name("addVideosFromDock")
}
