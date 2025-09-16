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
			name: "WebPShims",
			path: "Sources/ThirdParty/WebPShims",
			publicHeadersPath: ".",
			cSettings: [
				.define("WEBP_EMBEDDED", to: "1")
			]
		),
		.target(
			name: "PicsMinifierCore",
			dependencies: ["WebPShims"],
			path: "Sources/PicsMinifierCore",
			exclude: ["WebPStub.swift"],
			resources: [
				.process("Resources")
			]
		),
		.executableTarget(
			name: "PicsMinifierApp",
			dependencies: ["PicsMinifierCore"],
			path: "Sources/PicsMinifierApp"
		),
		.testTarget(
			name: "PicsMinifierAppTests",
			dependencies: ["PicsMinifierCore"],
			path: "Tests/PicsMinifierAppTests"
		)
	]
)


