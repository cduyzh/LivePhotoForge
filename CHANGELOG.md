# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-09

### Added
- **GUI 模式**: 基于 SwiftUI 的极简拖拽界面，支持批量导入与处理。
- **CLI 模式**: 内置同二进制的命令行工具，支持 `--import`、`-o` 输出目录、`--frame-time` 指定封面帧等。
- **原生引擎**: 彻底重构，基于纯 Swift 和 `AVFoundation` + `PHPhotoLibrary`，摆脱第三方依赖。
- **无损转换**: 针对 H.264 视频采用 Passthrough 模式，实现毫秒级零画质损耗封装转换。
- **自动相册导入**: 处理完成后自动通过 macOS 底层 API 完美配对并存入系统照片图库，实现与 iPhone 的无缝 iCloud 同步。
- **静态部署官网**: 新增 SEO 优化的项目展示静态主页，提供一键安装指令与下载链接。
