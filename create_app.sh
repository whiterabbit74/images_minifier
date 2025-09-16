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
mkdir -p PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset

# Extract icons from .icns file if it exists, otherwise use existing PNGs
if [ -f "AppIcons/AppIcon.icns" ]; then
    echo "📱 Extracting icons from .icns file..."
    # Extract various sizes from .icns
    iconutil -c iconset AppIcons/AppIcon.icns
    cp AppIcon.iconset/icon_16x16.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/16.png 2>/dev/null || echo "⚠️ 16px icon not found"
    cp AppIcon.iconset/icon_32x32.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/32.png 2>/dev/null || echo "⚠️ 32px icon not found"
    cp AppIcon.iconset/icon_64x64.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/64.png 2>/dev/null || echo "⚠️ 64px icon not found"
    cp AppIcon.iconset/icon_128x128.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/128.png 2>/dev/null || echo "⚠️ 128px icon not found"
    cp AppIcon.iconset/icon_256x256.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/256.png 2>/dev/null || echo "⚠️ 256px icon not found"
    cp AppIcon.iconset/icon_512x512.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/512.png 2>/dev/null || echo "⚠️ 512px icon not found"
    cp AppIcon.iconset/icon_512x512@2x.png PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/1024.png 2>/dev/null || echo "⚠️ 1024px icon not found"
    rm -rf AppIcon.iconset
else
    # Copy existing PNG icons
    echo "📱 Copying existing PNG icons..."
    find . -name "*.png" -path "*/AppIcons/*" -exec cp {} PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/ \; 2>/dev/null || echo "⚠️ Some PNG icons not found"
fi

# Create Contents.json for AppIcon
cat > PicsMinifier.app/Contents/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOF'
{
  "images" : [
    {
      "filename" : "16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "64.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "64x64"
    },
    {
      "filename" : "128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "1024.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Copy menu bar icon
cp compression_icon_simple.pdf PicsMinifier.app/Contents/Resources/ 2>/dev/null || echo "⚠️ Menu bar PDF icon not found"

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