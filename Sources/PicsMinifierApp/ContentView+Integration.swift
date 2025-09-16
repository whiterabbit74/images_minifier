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
                self.sessionStats.totalFiles = files.count
                self.sessionStats.processedFiles = 0
                self.sessionStats.totalOriginalSize = 0
                self.sessionStats.totalCompressedSize = 0
                self.sessionStats.errorCount = 0

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
					self.sessionStats.processedFiles = processed
					self.sessionStats.totalInBatch = total
				}
			},
			completion: { results in
				Task { @MainActor in
					// Update session stats with results
					for result in results where result.status == "success" {
						self.sessionStats.totalOriginalSize += result.originalSizeBytes
						self.sessionStats.totalCompressedSize += result.newSizeBytes
					}
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
				Task { @MainActor in
                                        let walker = FileWalker()
                                        let files = panel.urls.flatMap { walker.enumerateSupportedFiles(at: $0) }
                                        self.sessionStats.totalInBatch = files.count
                                        self.sessionStats.totalFiles = files.count
                                        self.sessionStats.processedFiles = 0
                                        self.sessionStats.totalOriginalSize = 0
                                        self.sessionStats.totalCompressedSize = 0
                                        self.sessionStats.errorCount = 0

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
								self.sessionStats.processedFiles = processed
								self.sessionStats.totalInBatch = total
							}
						},
						completion: { results in
							Task { @MainActor in
								// Update session stats with results
								for result in results where result.status == "success" {
									self.sessionStats.totalOriginalSize += result.originalSizeBytes
									self.sessionStats.totalCompressedSize += result.newSizeBytes
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


