#!/bin/bash
# 在 macOS 上运行本脚本,将 SPM 可执行文件打包成 .app
# 用法: ./build.sh
set -e

APP_NAME="MenuBarTranslator"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "==> swift build (release)"
swift build -c release

echo "==> 组装 .app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> 生成图标(iconset -> icns)"
if command -v iconutil &> /dev/null; then
    iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "   ⚠️ 未找到 iconutil(需要在 macOS 上运行),跳过图标生成"
fi

echo "==> 复制依赖库的资源 bundle(如 KeyboardShortcuts 自带的资源)"
shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
    echo "   - $(basename "$bundle")"
    cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
done
shopt -u nullglob

echo "==> 嵌入 Sparkle.framework(自动更新依赖的动态框架)"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_FRAMEWORK=$(find .build -type d -name "Sparkle.framework" 2>/dev/null | head -n 1)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    echo "   已嵌入: $SPARKLE_FRAMEWORK"
else
    echo "   ⚠️ 没找到 Sparkle.framework,自动更新功能可能无法运行。"
    echo "      如果确实找不到,把 'find .build -name Sparkle.framework' 的结果发我,我根据实际路径调整脚本。"
fi

echo "==> 完成: $APP_BUNDLE"
echo "首次运行前建议先本地签名(临时自签,避免每次重启权限失效):"
echo "  codesign --force --deep --sign - \"$APP_BUNDLE\""
echo ""
echo "正式分发给他人使用需要 Developer ID 签名 + 公证(notarize),否则辅助功能权限会反复失效。"
echo ""
echo "打开方式: open $APP_BUNDLE"
