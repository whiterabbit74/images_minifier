#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="${REPO_ROOT}/PicsMinifier.app"
EXECUTABLE="${REPO_ROOT}/.build/release/PicsMinifierApp"
APP_ICONS_DIR="${REPO_ROOT}/Resources/AppIcons"
CORE_RESOURCES="${REPO_ROOT}/Sources/PicsMinifierCore/Resources"

cd "$REPO_ROOT"

echo "🏗️ Creating PicsMinifier.app bundle..."
rm -rf "$APP_BUNDLE"

echo "📦 Building project (release)..."
swift build --configuration release

if [ ! -x "$EXECUTABLE" ]; then
    echo "❌ Expected executable not found at $EXECUTABLE" >&2
    exit 1
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "📄 Copying executable..."
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/PicsMinifierApp"

echo "📋 Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PicsMinifierApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.whiterabbit74.picsminifier</string>
    <key>CFBundleName</key>
    <string>PicsMinifier</string>
    <key>CFBundleDisplayName</key>
    <string>PicsMinifier</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.photography</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>jpg</string>
                <string>jpeg</string>
                <string>png</string>
                <string>gif</string>
                <string>webp</string>
                <string>heic</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Image Files</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

ASSET_TARGET="$APP_BUNDLE/Contents/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$(dirname "$ASSET_TARGET")"

if [ -d "$APP_ICONS_DIR/AppIcon.appiconset" ]; then
    echo "📱 Bundling AppIcon assets from Resources/AppIcons/AppIcon.appiconset"
    rm -rf "$ASSET_TARGET"
    cp -R "$APP_ICONS_DIR/AppIcon.appiconset" "$ASSET_TARGET"
elif [ -f "$APP_ICONS_DIR/icons.icns" ]; then
    echo "📱 icons.icns found, extracting fallback iconset"
    tmp_iconset="$(mktemp -d)"
    iconutil -c iconset "$APP_ICONS_DIR/icons.icns" -o "$tmp_iconset"
    mkdir -p "$ASSET_TARGET"
    cp "$tmp_iconset"/*.png "$ASSET_TARGET" 2>/dev/null || echo "⚠️ Failed to copy icons from icons.icns"
    rm -rf "$tmp_iconset"
else
    echo "⚠️ No AppIcon.appiconset available; copying loose PNGs from Resources/AppIcons"
    mkdir -p "$ASSET_TARGET"
    find "$APP_ICONS_DIR" -maxdepth 1 -name '*.png' -exec cp {} "$ASSET_TARGET" \;
fi

if [ -f "$APP_ICONS_DIR/menu_bar_icon.pdf" ]; then
    cp "$APP_ICONS_DIR/menu_bar_icon.pdf" "$APP_BUNDLE/Contents/Resources/compression_icon.pdf"
elif [ -f "$APP_ICONS_DIR/compression_icon.pdf" ]; then
    cp "$APP_ICONS_DIR/compression_icon.pdf" "$APP_BUNDLE/Contents/Resources/"
else
    echo "⚠️ Menu bar PDF icon not found"
fi

echo "🔧 Copying bundled tools..."
find "$CORE_RESOURCES" -type f \
    \( -name "cwebp" -o -name "dwebp" -o -name "gif2webp" -o -name "img2webp" -o -name "vwebp" -o -name "webpinfo" -o -name "webpmux" -o -name "gifsicle" \) \
    -exec cp {} "$APP_BUNDLE/Contents/Resources/" \; 2>/dev/null || echo "⚠️ Some bundled tools not found"

find "$CORE_RESOURCES" -name "README*.md" -exec cp {} "$APP_BUNDLE/Contents/Resources/" \; 2>/dev/null || echo "⚠️ Some README files not found"

mkdir -p "$APP_BUNDLE/Contents/Resources/ru.lproj"
mkdir -p "$APP_BUNDLE/Contents/Resources/en.lproj"

if command -v lsregister >/dev/null 2>&1; then
    echo "🔄 Registering with Launch Services..."
    lsregister -f "$APP_BUNDLE"
fi

echo "✅ PicsMinifier.app created successfully!"
echo "🚀 You can now run: open PicsMinifier.app"
