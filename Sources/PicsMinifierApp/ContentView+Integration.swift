import Foundation
import UniformTypeIdentifiers
import PicsMinifierCore
import SwiftUI
import AppKit

extension ContentView {
	@MainActor
	func handleDrop(providers: [NSItemProvider]) async {
		guard !isProcessing else { return }
		var droppedURLs: [URL] = []
		for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
			if let url = await loadFileURL(from: provider) {
				droppedURLs.append(url)
			}
		}

		guard !droppedURLs.isEmpty else { return }
		await consume(urls: droppedURLs)
	}

	private func loadFileURL(from provider: NSItemProvider) async -> URL? {
		await withCheckedContinuation { continuation in
			provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
				if let url = item as? URL {
					continuation.resume(returning: url)
				} else if let nsurl = item as? NSURL {
					continuation.resume(returning: nsurl as URL)
				} else if let data = item as? Data,
						let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
						let url = URL(string: string), url.isFileURL {
					continuation.resume(returning: url)
				} else {
					continuation.resume(returning: nil)
				}
			}
		}
	}

	@MainActor
	func consume(urls: [URL]) async {
		guard !urls.isEmpty else { return }

		let walker = FileWalker()
		var collected: [URL] = []
		for url in urls {
			collected.append(contentsOf: walker.enumerateSupportedFiles(at: url))
		}

		var seen = Set<String>()
		var unique: [URL] = []
		for file in collected {
			let key = file.standardizedFileURL.path
			if !seen.contains(key) {
				seen.insert(key)
				unique.append(file)
			}
		}

		guard !unique.isEmpty else { return }

		sessionStats.totalInBatch = unique.count
		sessionStats.totalFiles = unique.count
		sessionStats.processedFiles = 0
		sessionStats.totalOriginalSize = 0
		sessionStats.totalCompressedSize = 0
		sessionStats.errorCount = 0
		sessionStats.successfulFiles = 0
		sessionStats.failedFiles = 0
		sessionStats.skippedFiles = 0

		var settings = AppSettings()
		settings.preset = preset
		settings.saveMode = saveMode
		settings.preserveMetadata = preserveMetadata
		settings.convertToSRGB = convertToSRGB
		settings.enableGifsicle = enableGifsicle
		let md = UserDefaults.standard.object(forKey: "settings.maxDimension") as? Double ?? 0
		settings.maxDimension = md > 0 ? Int(md) : nil

		isProcessing = true

		SecureIntegrationLayer.shared.compressFiles(
			urls: unique,
			settings: settings,
			progressCallback: { processed, total in
				Task { @MainActor in
					self.sessionStats.processedFiles = processed
					self.sessionStats.totalInBatch = total
				}
			},
			completion: { results in
				Task { @MainActor in
					var successCount = 0
					var skippedCount = 0
					var failureCount = 0
					var totalOriginal: Int64 = 0
					var totalCompressed: Int64 = 0

					for result in results {
						let status = result.status.lowercased()
						switch status {
						case "success", "ok":
							successCount += 1
							totalOriginal += result.originalSizeBytes
							totalCompressed += result.newSizeBytes
						case "skipped":
							skippedCount += 1
						default:
							failureCount += 1
						}
					}

					self.sessionStats.successfulFiles = successCount
					self.sessionStats.skippedFiles = skippedCount
					self.sessionStats.failedFiles = failureCount
					self.sessionStats.processedFiles = successCount + skippedCount + failureCount
					self.sessionStats.totalOriginalSize = totalOriginal
					self.sessionStats.totalCompressedSize = totalCompressed
					self.sessionStats.errorCount = failureCount

					self.isProcessing = false
					AppUIManager.shared.showDockBounce()
				}
			}
		)
	}

	@MainActor
	func bindProgressUpdates() {
                guard progressObserverTokens.isEmpty else { return }

                let center = NotificationCenter.default

                let settingsToken = center.addObserver(forName: .settingsChanged, object: nil, queue: .main) { _ in
                        // Перечитываем настройки из UserDefaults
                        if let raw = UserDefaults.standard.string(forKey: "settings.saveMode"), let mode = SaveMode(rawValue: raw) {
                                self.saveMode = mode; self.previousSaveMode = mode
                        }
			if let rawPreset = UserDefaults.standard.string(forKey: "settings.preset"), let pr = CompressionPreset(rawValue: rawPreset) {
				self.preset = pr
			}
			self.preserveMetadata = UserDefaults.standard.object(forKey: "settings.preserveMetadata") as? Bool ?? self.preserveMetadata
			self.convertToSRGB = UserDefaults.standard.object(forKey: "settings.convertToSRGB") as? Bool ?? self.convertToSRGB
			self.enableGifsicle = UserDefaults.standard.object(forKey: "settings.enableGifsicle") as? Bool ?? self.enableGifsicle
			if let rawAppearance = UserDefaults.standard.string(forKey: "ui.appearanceMode"),
			   let mode = AppearanceMode(rawValue: rawAppearance) {
				self.appearanceMode = mode
			}
                        self.showDockIcon = UserDefaults.standard.object(forKey: "ui.showDockIcon") as? Bool ?? self.showDockIcon
                        self.showMenuBarIcon = UserDefaults.standard.object(forKey: "ui.showMenuBarIcon") as? Bool ?? self.showMenuBarIcon
                }
                progressObserverTokens.append(settingsToken)

                let openSettingsToken = center.addObserver(forName: .openSettings, object: nil, queue: .main) { _ in
                        self.showingSettings = true
                }
                progressObserverTokens.append(openSettingsToken)

                let openFilesToken = center.addObserver(forName: .openFiles, object: nil, queue: .main) { _ in
                        guard !self.isProcessing else { return }
                        self.pickFiles()
                }
                progressObserverTokens.append(openFilesToken)

                let openFolderToken = center.addObserver(forName: .openFolder, object: nil, queue: .main) { _ in
                        guard !self.isProcessing else { return }
                        self.pickFolder()
                }
                progressObserverTokens.append(openFolderToken)

                let cancelToken = center.addObserver(forName: .cancelProcessing, object: nil, queue: .main) { _ in
                        ProcessingManager.shared.cancel()
                        SecureIntegrationLayer.shared.cancelCompression()
                }
                progressObserverTokens.append(cancelToken)
        }

        @MainActor
        func teardownProgressUpdates() {
                for token in progressObserverTokens {
                        NotificationCenter.default.removeObserver(token)
                }
                progressObserverTokens.removeAll()
        }

	func pickFiles() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = true
		panel.allowedContentTypes = []
		panel.begin { resp in
			if resp == .OK {
				Task { await self.consume(urls: panel.urls) }
			}
		}
	}

	func pickFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.begin { resp in
			if resp == .OK, let url = panel.url {
				Task { await self.consume(urls: [url]) }
			}
		}
	}
}
