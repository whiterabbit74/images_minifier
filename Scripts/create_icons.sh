#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_ROOT="$REPO_ROOT/Resources/AppIcons"
ICNS_FILE="$ICON_ROOT/icons.icns"

if [ ! -f "$ICNS_FILE" ]; then
    echo "❌ icons.icns not found in Resources/AppIcons" >&2
    exit 1
fi

mkdir -p "$ICON_ROOT"

echo "🎨 Creating PicsMinifier app icons from $ICNS_FILE..."

iconutil -c iconset "$ICNS_FILE" -o "$ICON_ROOT/AppIcon.iconset"

if [ ! -d "$ICON_ROOT/AppIcon.iconset" ]; then
    echo "❌ Failed to extract iconset" >&2
    exit 1
fi

if [ ! -f "$ICON_ROOT/AppIcon.iconset/icon_16x16.png" ] && [ -f "$ICON_ROOT/AppIcon.iconset/icon_16x16@2x.png" ]; then
    sips -Z 16 "$ICON_ROOT/AppIcon.iconset/icon_16x16@2x.png" --out "$ICON_ROOT/AppIcon.iconset/icon_16x16.png" >/dev/null
fi

if [ ! -f "$ICON_ROOT/AppIcon.iconset/icon_32x32.png" ] && [ -f "$ICON_ROOT/AppIcon.iconset/icon_32x32@2x.png" ]; then
    sips -Z 32 "$ICON_ROOT/AppIcon.iconset/icon_32x32@2x.png" --out "$ICON_ROOT/AppIcon.iconset/icon_32x32.png" >/dev/null
fi

mkdir -p "$ICON_ROOT/AppIcon.appiconset"

for name in \
    icon_16x16.png \
    icon_16x16@2x.png \
    icon_32x32.png \
    icon_32x32@2x.png \
    icon_128x128.png \
    icon_128x128@2x.png \
    icon_256x256.png \
    icon_256x256@2x.png \
    icon_512x512.png \
    icon_512x512@2x.png; do
    cp "$ICON_ROOT/AppIcon.iconset/$name" "$ICON_ROOT/AppIcon.appiconset/$name" 2>/dev/null || true
done

while IFS=':' read -r src dest; do
    [ -z "$src" ] && continue
    if [ -f "$ICON_ROOT/AppIcon.appiconset/$src" ]; then
        cp "$ICON_ROOT/AppIcon.appiconset/$src" "$ICON_ROOT/$dest"
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

rm -rf "$ICON_ROOT/AppIcon.iconset"
rm -f "$ICON_ROOT/32@1x.png" "$ICON_ROOT/256@1x.png" "$ICON_ROOT/512@1x.png" "$ICON_ROOT/icon_1024.png" "$ICON_ROOT/icon_base.svg"

cat <<'JSON' > "$ICON_ROOT/AppIcon.appiconset/Contents.json"
{
  "images" : [
    { "filename" : "icon_16x16.png",      "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",      "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "✅ AppIcon.appiconset is ready in Resources/AppIcons"
