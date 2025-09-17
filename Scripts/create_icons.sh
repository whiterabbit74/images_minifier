#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_ROOT="$REPO_ROOT/Resources/AppIcons"
SOURCE_IMAGE="${1:-$REPO_ROOT/logo_photo.png}"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE" >&2
    exit 1
fi

mkdir -p "$ICON_ROOT/AppIcon.appiconset"

read -r width height < <(sips -g pixelWidth -g pixelHeight "$SOURCE_IMAGE" \
    | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}')

if [ -z "$width" ] || [ -z "$height" ]; then
    echo "❌ Unable to determine image dimensions" >&2
    exit 1
fi

if [ "$width" != "$height" ]; then
    echo "⚠️ Source image is not square (${width}x${height}); icons will be generated using the shorter side." >&2
fi

BASE_IMAGE="$ICON_ROOT/icon_base_1024.png"
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$BASE_IMAGE" >/dev/null

echo "🎨 Generating AppIcon.appiconset..."
while read -r filename size; do
    [ -z "$filename" ] && continue
    output="$ICON_ROOT/AppIcon.appiconset/$filename"
    sips -z "$size" "$size" "$BASE_IMAGE" --out "$output" >/dev/null
    case "$filename" in
        icon_16x16.png) cp "$output" "$ICON_ROOT/16.png" ;;
        icon_16x16@2x.png) cp "$output" "$ICON_ROOT/32.png" ;;
        icon_32x32@2x.png) cp "$output" "$ICON_ROOT/64.png" ;;
        icon_128x128.png) cp "$output" "$ICON_ROOT/128.png" ;;
        icon_128x128@2x.png) cp "$output" "$ICON_ROOT/256.png" ;;
        icon_256x256@2x.png) cp "$output" "$ICON_ROOT/512.png" ;;
        icon_512x512@2x.png) cp "$output" "$ICON_ROOT/1024.png" ;;
    esac
    echo "  • $filename (${size}x${size})"
done <<'MAP'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
MAP

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

ICNS_OUTPUT="$ICON_ROOT/icons.icns"
if command -v iconutil >/dev/null 2>&1; then
    tmp_dir="$(mktemp -d)"
    cp -R "$ICON_ROOT/AppIcon.appiconset" "$tmp_dir/"
    if iconutil -c icns "$tmp_dir/AppIcon.appiconset" -o "$ICNS_OUTPUT" 2>/dev/null; then
        echo "🛠️  Exported $ICNS_OUTPUT"
    else
        echo "⚠️  Failed to export $ICNS_OUTPUT"
    fi
    rm -rf "$tmp_dir"
else
    echo "⚠️ iconutil not available; skipping .icns export"
fi

rm -f "$BASE_IMAGE"

echo "✅ App icon assets updated"
