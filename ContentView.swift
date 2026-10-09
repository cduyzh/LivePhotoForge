import SwiftUI
import UniformTypeIdentifiers
import Photos

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var vm = ConversionViewModel()
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            dropZone
            Divider()
            if vm.items.isEmpty {
                emptyState
            } else {
                videoList
            }
            Divider()
            bottomBar
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addVideosFromDock)) { note in
            if let urls = note.object as? [URL] {
                urls.forEach { vm.addVideo(url: $0) }
            }
        }
    }

    // MARK: - 拖拽区域
    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(isDragging ? .blue : .secondary)
            Text("拖拽视频文件到这里")
                .font(.title3.weight(.medium))
            Text("支持 MP4 / MOV / M4V / MKV")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("或 点击选择文件…") { openFilePicker() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.accentColor.opacity(0.06) : Color.clear)
                )
        )
        .padding()
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.live.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("拖入视频即可开始")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 视频列表
    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(vm.items) { item in
                    VideoItemRow(item: item, onRemove: { vm.remove(item) })
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 底栏
    private var bottomBar: some View {
        HStack {
            Text(vm.statusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()

            if !vm.items.isEmpty {
                Button(role: .destructive) {
                    vm.clearCompleted()
                } label: {
                    Label("清除已完成", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(vm.completedCount == 0)
            }

            Button {
                vm.startConversion()
            } label: {
                Label(vm.isRunning ? "转换中…" : "开始转换", systemImage: "bolt.fill")
                    .frame(minWidth: 80)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(vm.pendingCount == 0 || vm.isRunning)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - 文件选择器
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .mpeg4Movie, .quickTimeMovie, .movie, .video,
            UTType(filenameExtension: "mkv")!,
            UTType(filenameExtension: "m4v")!,
        ]
        if panel.runModal() == .OK {
            panel.urls.forEach { vm.addVideo(url: $0) }
        }
    }

    // MARK: - Drop 处理
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let validExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data,
                      let path = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .removingPercentEncoding,
                      let url = URL(string: path) ?? URL(fileURLWithPath: path) as URL?
                else { return }

                let fileURL: URL
                if url.scheme == "file" {
                    fileURL = url
                } else {
                    fileURL = URL(fileURLWithPath: url.path)
                }

                guard validExts.contains(fileURL.pathExtension.lowercased()) else { return }
                DispatchQueue.main.async { vm.addVideo(url: fileURL) }
            }
        }
        return true
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: - 单行视频条目
struct VideoItemRow: View {
    @ObservedObject var item: VideoItem
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            Group {
                if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 72, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // 信息列
            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Label(item.durationText, systemImage: "clock")
                    Label(item.resolution, systemImage: "rectangle.split.3x3")
                    Label(item.fileSize, systemImage: "doc")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // 状态
            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .contextMenu {
            Button("移除") { onRemove() }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if item.status.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
            Image(systemName: item.status.icon)
                .foregroundStyle(statusColor)
            Text(item.status.label)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed: return .green
        case .failed:    return .red
        default:         return .secondary
        }
    }
}

// MARK: ─────────────────────────────────────────────
// MARK: - ViewModel
class ConversionViewModel: ObservableObject {
    @Published var items: [VideoItem] = []
    @Published var isRunning = false

    var pendingCount: Int { items.filter { $0.status == .pending }.count }
    var completedCount: Int { items.filter { $0.status == .completed }.count }

    var statusSummary: String {
        if items.isEmpty { return "" }
        let done = items.filter { $0.status == .completed }.count
        let fail = items.filter { if case .failed = $0.status { return true }; return false }.count
        let total = items.count
        if isRunning { return "转换中… \(done)/\(total)" }
        if fail > 0 { return "共 \(total) 个，成功 \(done)，失败 \(fail)" }
        if done == total { return "全部完成 ✓" }
        return "共 \(total) 个待转换"
    }

    func addVideo(url: URL) {
        // 去重
        guard !items.contains(where: { $0.url == url }) else { return }
        items.append(VideoItem(url: url))
    }

    func remove(_ item: VideoItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed }
    }

    func startConversion() {
        guard !isRunning else { return }
        isRunning = true

        Task { @MainActor in
            await ConversionEngine.processBatch(items)
            isRunning = false
        }
    }
}
