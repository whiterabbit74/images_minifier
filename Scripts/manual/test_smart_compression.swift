#!/usr/bin/env swift

import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let scriptsDir = scriptURL.deletingLastPathComponent()
let repoRoot = scriptsDir.deletingLastPathComponent()
let imagesDir = repoRoot.appendingPathComponent("Resources/ManualTests/Images")
let resultsDir = repoRoot.appendingPathComponent("Resources/ManualTests/Results")

let fileManager = FileManager.default
try? fileManager.createDirectory(at: resultsDir, withIntermediateDirectories: true)

func testTool(name: String, executablePath: String, inputName: String, arguments: [String]) {
    let inputURL = imagesDir.appendingPathComponent(inputName)
    guard fileManager.fileExists(atPath: inputURL.path) else { return }

    print("\n🔧 Testing \(name)...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments

    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("✅ \(name) compression successful!")
        } else {
            print("❌ \(name) compression failed with status \(process.terminationStatus)")
        }
    } catch {
        print("❌ \(name) error: \(error)")
    }
}

print("🔧 Testing SmartCompressor Tools")
print("================================")

testTool(
    name: "MozJPEG",
    executablePath: "/opt/homebrew/opt/mozjpeg/bin/cjpeg",
    inputName: "test.jpg",
    arguments: [
        "-quality", "85",
        "-optimize",
        "-progressive",
        "-outfile", resultsDir.appendingPathComponent("test_mozjpeg.jpg").path,
        imagesDir.appendingPathComponent("test.jpg").path
    ]
)

testTool(
    name: "Oxipng",
    executablePath: "/opt/homebrew/bin/oxipng",
    inputName: "test.png",
    arguments: [
        "--opt", "3",
        "--strip", "safe",
        "--out", resultsDir.appendingPathComponent("test_oxipng.png").path,
        imagesDir.appendingPathComponent("test.png").path
    ]
)

testTool(
    name: "Gifsicle",
    executablePath: "/opt/homebrew/bin/gifsicle",
    inputName: "test.gif",
    arguments: [
        "--optimize=3",
        "--output", resultsDir.appendingPathComponent("test_gifsicle.gif").path,
        imagesDir.appendingPathComponent("test.gif").path
    ]
)

print("\n🎉 Tool testing complete!")
print("Check \(resultsDir.path) for compressed files.")
