#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="${REPO_ROOT}/Sources/PicsMinifierCore/Resources"

echo "📂 Ensuring resources directory exists..."
mkdir -p "$RESOURCES_DIR"

# List of tools to look for
# Format: "tool_name:homebrew_package_name"
TOOLS=(
    "cjpeg:mozjpeg"
    "oxipng:oxipng"
    "gifsicle:gifsicle"
    "avifenc:libavif"
)

# Standard Homebrew paths
BREW_PREFIX_ARM="/opt/homebrew"
BREW_PREFIX_INTEL="/usr/local"

echo "🔍 Searching for tools..."

for item in "${TOOLS[@]}"; do
    tool="${item%%:*}"
    package="${item##*:}"
    
    echo "   Checking for $tool ($package)..."
    
    found_path=""
    
    # Check specific mozjpeg location (it's often keg-only)
    if [ "$tool" == "cjpeg" ]; then
        candidates=(
            "$BREW_PREFIX_ARM/opt/mozjpeg/bin/cjpeg"
            "$BREW_PREFIX_INTEL/opt/mozjpeg/bin/cjpeg"
        )
    else
        candidates=(
            "$BREW_PREFIX_ARM/bin/$tool"
            "$BREW_PREFIX_INTEL/bin/$tool"
            "$(which $tool 2>/dev/null || true)"
        )
    fi

    for candidate in "${candidates[@]}"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            found_path="$candidate"
            break
        fi
    done

    if [ -n "$found_path" ]; then
        echo "      ✅ Found at $found_path"
        cp "$found_path" "$RESOURCES_DIR/"
        echo "      📥 Copied to Resources/"
    else
        echo "      ❌ NOT FOUND. Please install via brew: brew install $package"
    fi
done

echo "🎉 Done. Check the output above for any missing tools."
