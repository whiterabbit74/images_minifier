#!/bin/bash

echo "🏗️ Creating PicsMinifier.app bundle..."

# Remove old app if exists
rm -rf PicsMinifier.app

# Build the project
echo "📦 Building project..."
swift build --configuration release

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p PicsMinifier.app/Contents/MacOS
mkdir -p PicsMinifier.app/Contents/Resources

# Copy executable
echo "📄 Copying executable..."
cp .build/release/PicsMinifierApp PicsMinifier.app/Contents/MacOS/

# Create Info.plist
echo "📋 Creating Info.plist..."
cat > PicsMinifier.app/Contents/Info.plist << 'EOF'
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
EOF

# Copy resources (bundled tools and assets)
echo "🎨 Copying resources..."

# Create Assets.xcassets structure and copy icons
mkdir -p PicsMinifier.app/Contents/Resources/Assets.xcassets

appicon_target="PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset"

if [ -d "AppIcons/AppIcon.appiconset" ]; then
    echo "📱 Bundling AppIcon assets from AppIcons/AppIcon.appiconset"
    rm -rf "$appicon_target"
    cp -R AppIcons/AppIcon.appiconset "$appicon_target"
elif [ -f "icons.icns" ]; then
    echo "📱 icons.icns found, extracting fallback iconset"
    tmp_iconset="$(mktemp -d)"
    iconutil -c iconset icons.icns -o "$tmp_iconset"
    mkdir -p "$appicon_target"
    cp "$tmp_iconset"/*.png "$appicon_target" 2>/dev/null || echo "⚠️ Failed to copy icons from icons.icns"
    rm -rf "$tmp_iconset"
else
    echo "⚠️ AppIcons/AppIcon.appiconset not found; using whatever PNGs exist under AppIcons/"
    mkdir -p "$appicon_target"
    find AppIcons -maxdepth 1 -name '*.png' -exec cp {} "$appicon_target" \;
fi

# Copy menu bar icon
if [ -f "AppIcons/menu_bar_icon.pdf" ]; then
    cp AppIcons/menu_bar_icon.pdf PicsMinifier.app/Contents/Resources/compression_icon.pdf
elif [ -f "compression_icon.pdf" ]; then
    cp compression_icon.pdf PicsMinifier.app/Contents/Resources/
else
    echo "⚠️ Menu bar PDF icon not found"
fi

# Copy bundled tools
echo "🔧 Copying bundled tools..."
find Sources/PicsMinifierCore/Resources -type f \( -name "cwebp" -o -name "dwebp" -o -name "gif2webp" -o -name "img2webp" -o -name "vwebp" -o -name "webpinfo" -o -name "webpmux" -o -name "gifsicle" \) -exec cp {} PicsMinifier.app/Contents/Resources/ \; 2>/dev/null || echo "⚠️ Some bundled tools not found"

# Copy README files for bundled tools
find Sources/PicsMinifierCore/Resources -name "README*.md" -exec cp {} PicsMinifier.app/Contents/Resources/ \; 2>/dev/null || echo "⚠️ Some README files not found"

# Copy localization files
echo "🌐 Copying localizations..."
mkdir -p PicsMinifier.app/Contents/Resources/ru.lproj
mkdir -p PicsMinifier.app/Contents/Resources/en.lproj

# Make executable
chmod +x PicsMinifier.app/Contents/MacOS/PicsMinifierApp

# Register with Launch Services
echo "🔄 Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ./PicsMinifier.app

# Refresh Dock
echo "🔄 Refreshing Dock..."
killall Dock 2>/dev/null || echo "Dock not running"

echo "✅ PicsMinifier.app created successfully!"
echo "🚀 You can now run: open PicsMinifier.app"
