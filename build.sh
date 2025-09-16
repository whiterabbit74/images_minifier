#!/bin/bash
set -e

echo "🚀 Fast build script"

# Create build directory
mkdir -p .fastbuild

# Compile Core module files directly
cd Sources/PicsMinifierCore
echo "Compiling Core..."
swiftc -emit-module -module-name PicsMinifierCore \
    Models.swift \
    SecurityUtils.swift \
    SafeStatsStore.swift \
    SafeCSVLogger.swift \
    WebPEncoderStub.swift \
    SecureIntegrationLayer.swift \
    -o ../../.fastbuild/

cd ../../

echo "Compiling App..."
cd Sources/PicsMinifierApp
swiftc -I ../../.fastbuild \
    -L ../../.fastbuild \
    AppMain.swift \
    -o ../../.fastbuild/PicsMinifierApp

cd ../../
echo "✅ Build complete in .fastbuild/"