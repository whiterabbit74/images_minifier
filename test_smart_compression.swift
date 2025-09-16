#!/usr/bin/env swift

import Foundation

// Simple test to verify SmartCompressor tools are working
print("🔧 Testing SmartCompressor Tools")
print("===============================")

// Test MozJPEG
if FileManager.default.fileExists(atPath: "TestImages/test.jpg") {
    print("\n📸 Testing MozJPEG compression...")

    let mozjpegResult = Process()
    mozjpegResult.executableURL = URL(fileURLWithPath: "/opt/homebrew/opt/mozjpeg/bin/cjpeg")
    mozjpegResult.arguments = [
        "-quality", "85",
        "-optimize",
        "-progressive",
        "-outfile", "TestResults/test_mozjpeg.jpg",
        "TestImages/test.jpg"
    ]

    do {
        try mozjpegResult.run()
        mozjpegResult.waitUntilExit()
        if mozjpegResult.terminationStatus == 0 {
            print("✅ MozJPEG compression successful!")
        } else {
            print("❌ MozJPEG compression failed")
        }
    } catch {
        print("❌ MozJPEG error: \(error)")
    }
}

// Test Oxipng
if FileManager.default.fileExists(atPath: "TestImages/test.png") {
    print("\n🖼 Testing Oxipng compression...")

    let oxipngResult = Process()
    oxipngResult.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/oxipng")
    oxipngResult.arguments = [
        "--opt", "3",
        "--strip", "safe",
        "--out", "TestResults/test_oxipng.png",
        "TestImages/test.png"
    ]

    do {
        try oxipngResult.run()
        oxipngResult.waitUntilExit()
        if oxipngResult.terminationStatus == 0 {
            print("✅ Oxipng compression successful!")
        } else {
            print("❌ Oxipng compression failed")
        }
    } catch {
        print("❌ Oxipng error: \(error)")
    }
}

// Test Gifsicle
if FileManager.default.fileExists(atPath: "TestImages/test.gif") {
    print("\n🎞 Testing Gifsicle compression...")

    let gifsicleResult = Process()
    gifsicleResult.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gifsicle")
    gifsicleResult.arguments = [
        "--optimize=3",
        "--output", "TestResults/test_gifsicle.gif",
        "TestImages/test.gif"
    ]

    do {
        try gifsicleResult.run()
        gifsicleResult.waitUntilExit()
        if gifsicleResult.terminationStatus == 0 {
            print("✅ Gifsicle compression successful!")
        } else {
            print("❌ Gifsicle compression failed")
        }
    } catch {
        print("❌ Gifsicle error: \(error)")
    }
}

print("\n🎉 Tool testing complete!")
print("Check TestResults/ for compressed files.")