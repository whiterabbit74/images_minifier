import Foundation
import UniformTypeIdentifiers
import PicsMinifierCore
import SwiftUI
import AppKit

extension ContentView {
	func handleDrop(providers: [NSItemProvider]) async {
		for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
			_ = provider.loadObject(ofClass: URL.self) { url, _ in
				guard let url else { return }
				Task { await self.consume(url: url) }
			}
		}
	}

	@MainActor
	func consume(url: URL) async {
		let walker = FileWalker()
		let files = walker.enumerateSupportedFiles(at: url)
		self.sessionStats.totalInBatch = files.count

		var settings = AppSettings()
		settings.preset = preset
		settings.saveMode = saveMode
		settings.preserveMetadata = preserveMetadata
		settings.convertToSRGB = convertToSRGB
		settings.enableGifsicle = enableGifsicle
		let md = UserDefaults.standard.object(forKey: "settings.maxDimension") as? Double ?? 0
		settings.maxDimension = md > 0 ? Int(md) : nil

		self.isProcessing = true

		// Use SecureIntegrationLayer for processing
		SecureIntegrationLayer.shared.compressFiles(
			urls: files,
			settings: settings,
			progressCallback: { processed, total in
				Task { @MainActor in
					self.sessionStats.processedCount = processed
					self.sessionStats.totalInBatch = total
				}
			},
			completion: { results in
				Task { @MainActor in
					// Update session stats with results
					for result in results where result.status == "success" {
						let saved = max(0, result.originalSizeBytes - result.newSizeBytes)
						self.sessionStats.savedBytes += saved
					}
					self.isProcessing = false
					AppUIManager.shared.showDockBounce()
				}
			}
		)
	}

	@MainActor
	func bindProgressUpdates() {

		NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { _ in
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

		NotificationCenter.default.addObserver(forName: .openSettings, object: nil, queue: .main) { _ in
			self.showingSettings = true
		}

		NotificationCenter.default.addObserver(forName: .openFiles, object: nil, queue: .main) { _ in
			guard !self.isProcessing else { return }
			self.pickFiles()
		}

		NotificationCenter.default.addObserver(forName: .openFolder, object: nil, queue: .main) { _ in
			guard !self.isProcessing else { return }
			self.pickFolder()
		}

		NotificationCenter.default.addObserver(forName: .cancelProcessing, object: nil, queue: .main) { _ in
			ProcessingManager.shared.cancel()
		}
	}

	func pickFiles() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = true
		panel.allowedContentTypes = []
		panel.begin { resp in
			if resp == .OK {
				Task { @MainActor in
					let walker = FileWalker()
					let files = panel.urls.flatMap { walker.enumerateSupportedFiles(at: $0) }
					self.sessionStats.totalInBatch = files.count

					var settings = AppSettings()
					settings.preset = preset
					settings.saveMode = saveMode
					settings.preserveMetadata = preserveMetadata
					settings.convertToSRGB = convertToSRGB
					settings.enableGifsicle = enableGifsicle

					self.isProcessing = true

					// Use SecureIntegrationLayer for processing
					SecureIntegrationLayer.shared.compressFiles(
						urls: files,
						settings: settings,
						progressCallback: { processed, total in
							Task { @MainActor in
								self.sessionStats.processedCount = processed
								self.sessionStats.totalInBatch = total
							}
						},
						completion: { results in
							Task { @MainActor in
								// Update session stats with results
								for result in results where result.status == "success" {
									let saved = max(0, result.originalSizeBytes - result.newSizeBytes)
									self.sessionStats.savedBytes += saved
								}
								self.isProcessing = false
								AppUIManager.shared.showDockBounce()
							}
						}
					)
				}
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
				Task { await self.consume(url: url) }
			}
		}
	}
}


