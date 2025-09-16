// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "PicsMinifier",
	defaultLocalization: "ru",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.executable(name: "PicsMinifierApp", targets: ["PicsMinifierApp"]),
		.library(name: "PicsMinifierCore", targets: ["PicsMinifierCore"])
	],
	targets: [
		.target(
			name: "PicsMinifierCore",
			dependencies: [],
			path: "Sources/PicsMinifierCore",
			exclude: ["WebPEncoder.swift"],  // Temporarily exclude WebP
			resources: [
				.process("Resources")
			]
		),
		.executableTarget(
			name: "PicsMinifierApp",
			dependencies: ["PicsMinifierCore"],
			path: "Sources/PicsMinifierApp",
			sources: ["AppMain.swift", "Notifications.swift", "AppUIManager.swift", "ProcessingManager.swift", "ContentView.swift", "SettingsView.swift", "ContentView+Integration.swift"]
		),
		.testTarget(
			name: "PicsMinifierAppTests",
			dependencies: ["PicsMinifierCore"],
			path: "Tests/PicsMinifierAppTests"
		)
	]
)