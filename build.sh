#!/bin/bash
# 在 macOS 上运行本脚本,将 SPM 可执行文件打包成 .app
# 用法: ./build.sh
set -e

APP_NAME="Poptro"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
DIST_DIR="dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"

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

echo "==> 本地 ad-hoc 签名(避免每次重新编译后系统又要求重新授权辅助功能权限)"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> 生成拖拽安装 DMG"
mkdir -p "$DIST_DIR"
DMG_STAGE=$(mktemp -d)
ditto "$APP_BUNDLE" "$DMG_STAGE/$APP_BUNDLE"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "Poptro" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGE"

echo "==> 生成 Sparkle / GitHub Release ZIP"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> 完成: $APP_BUNDLE"
echo ""
echo "这是 ad-hoc 自签名,不是 Apple 官方认证开发者签名。"
echo "如果这份 .app 是分发给别人(而不是自己本机用),对方首次打开会被 Gatekeeper 拦截,"
echo "需要去 系统设置 -> 隐私与安全性 里点\"仍要打开\"授权一次,具体说明见 README。"
echo ""
echo "如果办了 Apple Developer Program 账号,想要不需要用户手动授权的正式签名版本,"
echo "参考 .github/workflows/release-notarized.yml 里的公证流程。"
echo ""
echo "打开方式: open $APP_BUNDLE"
echo "DMG 安装包: ${DMG_PATH}（打开后将 App 拖入 Applications）"
echo "ZIP 更新包: ${ZIP_PATH}"
