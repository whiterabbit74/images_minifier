#!/bin/bash

set -euo pipefail

echo "🎨 Creating PicsMinifier app icons from icons.icns..."

if [ ! -f "icons.icns" ]; then
    echo "❌ icons.icns not found in project root"
    exit 1
fi

mkdir -p AppIcons

# Extract all png renditions from the provided icns file
iconutil -c iconset icons.icns -o AppIcons/AppIcon.iconset

if [ ! -d "AppIcons/AppIcon.iconset" ]; then
    echo "❌ Failed to extract iconset"
    exit 1
fi

# Generate missing 1x assets for small sizes from 2x variants
if [ ! -f "AppIcons/AppIcon.iconset/icon_16x16.png" ] && [ -f "AppIcons/AppIcon.iconset/icon_16x16@2x.png" ]; then
    sips -Z 16 AppIcons/AppIcon.iconset/icon_16x16@2x.png --out AppIcons/AppIcon.iconset/icon_16x16.png >/dev/null
fi

if [ ! -f "AppIcons/AppIcon.iconset/icon_32x32.png" ] && [ -f "AppIcons/AppIcon.iconset/icon_32x32@2x.png" ]; then
    sips -Z 32 AppIcons/AppIcon.iconset/icon_32x32@2x.png --out AppIcons/AppIcon.iconset/icon_32x32.png >/dev/null
fi

mkdir -p AppIcons/AppIcon.appiconset

# Copy the icon pngs into the appiconset bundle
cp AppIcons/AppIcon.iconset/icon_16x16.png AppIcons/AppIcon.appiconset/icon_16x16.png 2>/dev/null || true
cp AppIcons/AppIcon.iconset/icon_16x16@2x.png AppIcons/AppIcon.appiconset/icon_16x16@2x.png 2>/dev/null || true
cp AppIcons/AppIcon.iconset/icon_32x32.png AppIcons/AppIcon.appiconset/icon_32x32.png 2>/dev/null || true
cp AppIcons/AppIcon.iconset/icon_32x32@2x.png AppIcons/AppIcon.appiconset/icon_32x32@2x.png 2>/dev/null || true
cp AppIcons/AppIcon.iconset/icon_128x128.png AppIcons/AppIcon.appiconset/icon_128x128.png
cp AppIcons/AppIcon.iconset/icon_128x128@2x.png AppIcons/AppIcon.appiconset/icon_128x128@2x.png
cp AppIcons/AppIcon.iconset/icon_256x256.png AppIcons/AppIcon.appiconset/icon_256x256.png
cp AppIcons/AppIcon.iconset/icon_256x256@2x.png AppIcons/AppIcon.appiconset/icon_256x256@2x.png
cp AppIcons/AppIcon.iconset/icon_512x512.png AppIcons/AppIcon.appiconset/icon_512x512.png
cp AppIcons/AppIcon.iconset/icon_512x512@2x.png AppIcons/AppIcon.appiconset/icon_512x512@2x.png

# Also expose a flat set of PNGs in AppIcons/ for quick inspection
while IFS=':' read -r src dest; do
    [ -z "$src" ] && continue
    if [ -f "AppIcons/AppIcon.appiconset/$src" ]; then
        cp "AppIcons/AppIcon.appiconset/$src" "AppIcons/$dest"
    fi
done <<'MAP'
icon_16x16.png:16.png
icon_16x16@2x.png:32.png
icon_32x32@2x.png:64.png
icon_128x128.png:128.png
icon_128x128@2x.png:256.png
icon_256x256@2x.png:512.png
icon_512x512@2x.png:1024.png
MAP

rm -rf AppIcons/AppIcon.iconset
rm -f AppIcons/32@1x.png AppIcons/256@1x.png AppIcons/512@1x.png AppIcons/icon_1024.png AppIcons/icon_base.svg

cat <<'JSON' > AppIcons/AppIcon.appiconset/Contents.json
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "✅ AppIcon.appiconset is ready in AppIcons/"
