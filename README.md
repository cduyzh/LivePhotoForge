# LivePhotoForge

> ⚡️ 极速、原生的 macOS 视频转苹果实况图 (Live Photo) 桌面与命令行双模工具。

[![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.5+-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

LivePhotoForge 是一款专为 Mac 用户打造的工具，用于将普通的 `.mp4`、`.mov` 等视频文件，无损、极速地转换为真正的苹果实况图 (Live Photo)，并**全自动导入到您的 Mac 统相册中**。一旦导入，iCloud 会瞬间将其同步到您的 iPhone。

## ✨ 核心特性

- **双模架构**：提供极简的拖拽式 GUI 界面，同时内置强大的 CLI 命令行模式。
- **100% 苹果原生**：抛弃繁杂的第三方依赖，完全基于纯 Swift 和 `AVFoundation` / `Photos.framework` 开发。
- **极速无损**：对于 H.264 视频，采用流复制 (Passthrough) 换壳技术，零重新编码，处理 10 秒视频仅需 ~0.04 秒。
- **底层配对**：利用 `PHAssetCreationRequest` 在系统底层完美“熔合”图片与视频，生成的实况图与 iPhone 原生拍摄 100% 兼容。
- **完全离线**：本地处理，不上传任何数据，保护您的隐私。

## 📥 下载与安装

### 方式一：下载 macOS 图形界面 App (推荐)

前往 [Releases 页面](https://github.com/cduyzh/LivePhotoForge/releases) 下载最新的 `LivePhotoForge.dmg`。
双击打开 DMG，将 `LivePhotoForge` 拖入您的 `Applications` (应用程序) 文件夹即可。

### 方式二：通过 CLI 一键安装

如果您偏爱命令行，可以通过以下命令直接下载 CLI 二进制文件到全局路径（支持双模调用）：

```bash
sudo curl -L "https://github.com/cduyzh/LivePhotoForge/releases/latest/download/LivePhotoForge" -o /usr/local/bin/livephoto && sudo chmod +x /usr/local/bin/livephoto
```

## 🚀 快速使用

### 图形界面 (GUI)
1. 打开应用程序中的 `LivePhotoForge`。
2. 首次打开时，根据系统提示允许“照片”访问权限。
3. 将您想转换的视频（支持批量）拖入窗口中。
4. 点击“开始转换”，处理完成后即可在 Mac 自带的“照片”应用中看到它们！

### 命令行 (CLI)

安装好 `livephoto` 命令后，您可以在任何终端中使用它：

```bash
# 1. 自动转换并直接导入相册（最常用）
livephoto video.mp4

# 2. 截取视频第 2.5 秒作为实况图封面，并导入相册
livephoto --frame-time 2.5 video.mp4

# 3. 批量处理并导入
livephoto *.mp4

# 4. 不导入相册，仅输出处理好的 .jpg 和 .mov 配对文件到指定目录
livephoto -o ~/Desktop/LivePhotos/ video1.mp4

# 5. 查看完整帮助
livephoto --help
```

## 🛠 技术原理

苹果实况图并非单一文件，而是通过共享同一个 `UUID` 的图像 (`.heic`/`.jpg` 中的 MakerNote) 和视频 (`.mov` 中的 QuickTime mdta) 组成的组合体。
LivePhotoForge 直接跳过了手动拼接字节的容易出错的环节：
1. 使用 `AVAssetImageGenerator` 提取高质量封面。
2. 使用 `AVAssetExportSession` 将容器无损转为 `.mov`。
3. 调用 macOS 原生 `PHAssetCreationRequest.addResource` 接口，将两部分直接提交给操作系统的 Photos 守护进程，由苹果底层自动补全 UUID 配对并注入系统图库。

## 📄 许可证
本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。
