#!/bin/bash
set -e

APP_NAME="LivePhotoForge"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
SWIFT_FILES=(
    main.swift
    LivePhotoForgeApp.swift
    VideoItem.swift
    ConversionEngine.swift
    CLIHandler.swift
    ContentView.swift
)

echo "╔══════════════════════════════════════╗"
echo "║   LivePhotoForge 构建脚本             ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 清理 ──
rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# ── 编译 ──
echo "🔨 编译中…"
xcrun swiftc \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework SwiftUI \
    -framework Photos \
    -framework AVFoundation \
    -framework UniformTypeIdentifiers \
    -framework ImageIO \
    -framework CoreImage \
    -O \
    -o "$CONTENTS/MacOS/$APP_NAME" \
    "${SWIFT_FILES[@]}"

echo "   ✅ 编译成功"

# ── 资源 ──
echo "📦 打包资源…"
cp Info.plist "$CONTENTS/"

# ── 创建 CLI 符号链接（可选，方便终端使用） ──
ln -sf "../App/$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    "../$APP_NAME" 2>/dev/null || true

# ── 签名 ──
echo "🔏 Ad-hoc 签名…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

# ── 结果 ──
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
BIN_SIZE=$(du -sh "$CONTENTS/MacOS/$APP_NAME" | cut -f1)

echo ""
echo "══════════════════════════════════════"
echo "✅ 构建完成！"
echo ""
echo "  App:     $APP_BUNDLE  ($APP_SIZE)"
echo "  Binary:  $BIN_SIZE"
echo ""
echo "  GUI 模式:  open $APP_BUNDLE"
echo "  CLI 模式:  $CONTENTS/MacOS/$APP_NAME --help"
echo ""
echo "  或创建全局命令:"
echo "    sudo ln -sf \$(pwd)/$CONTENTS/MacOS/$APP_NAME /usr/local/bin/livephoto"
echo "    livephoto video.mp4"
echo "══════════════════════════════════════"
