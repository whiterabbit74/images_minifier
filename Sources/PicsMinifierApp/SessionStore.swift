import SwiftUI
import PicsMinifierCore
import UniformTypeIdentifiers

@MainActor
class SessionStore: ObservableObject {
    @Published var processedFiles: [ProcessedFile] = []
    @Published var stats: SessionStats = .init()
    @Published var isProcessing: Bool = false
    @Published var currentFileName: String = ""
    
    // Dependencies
    var settingsStore: SettingsStore?
    
    @MainActor
    func handleDrop(providers: [NSItemProvider]) async {
        print("DEBUG: handleDrop started for \(providers.count) providers")
        guard !isProcessing else { 
            print("DEBUG: handleDrop aborted (already processing)")
            return 
        }
        var droppedURLs: [URL] = []
        for provider in providers {
            print("DEBUG: Loading item for provider: \(provider.registeredTypeIdentifiers)")
            if let url = await loadFileURL(from: provider) {
                print("DEBUG: Resolved URL: \(url.path)")
                droppedURLs.append(url)
            } else {
                print("DEBUG: Failed to resolve URL for provider")
            }
        }

        guard !droppedURLs.isEmpty else { 
            print("DEBUG: No URLs extracted from drop")
            return 
        }
        await consume(urls: droppedURLs)
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        print("DEBUG: loadFileURL for provider with types: \(provider.registeredTypeIdentifiers)")
        // Try file-url identifier directly as string
        if let url = await loadItem(from: provider, typeIdentifier: "public.file-url") { return url }
        // Try fileURL
        if let url = await loadItem(from: provider, typeIdentifier: UTType.fileURL.identifier) { return url }
        // Try url
        if let url = await loadItem(from: provider, typeIdentifier: UTType.url.identifier) { return url }
        // Try item
        if let url = await loadItem(from: provider, typeIdentifier: UTType.item.identifier) { return url }
        
        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { return nil }
        print("DEBUG: Provider conforms to \(typeIdentifier), loading...")
        
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error = error {
                    print("DEBUG: loadItem error for \(typeIdentifier): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                var resolvedURL: URL? = nil

                if let url = item as? URL {
                    resolvedURL = url
                } else if let nsurl = item as? NSURL {
                    resolvedURL = nsurl as URL
                } else if let data = item as? Data {
                    if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                        resolvedURL = URL(string: string) ?? URL(fileURLWithPath: string)
                    }
                } else if let string = item as? String {
                    resolvedURL = URL(string: string) ?? URL(fileURLWithPath: string)
                }

                if let url = resolvedURL {
                    print("DEBUG: loadItem resolved URL: \(url.path)")
                    // Handle security scope if needed
                    if url.startAccessingSecurityScopedResource() {
                        print("DEBUG: Accessed security scoped resource: \(url.path)")
                        // Note: We don't stopAccessing here because we need to read it later in FileWalker.
                        // We should ideally stop it after consumption, but for now we'll keep it simple.
                    }
                    continuation.resume(returning: url)
                } else {
                    print("DEBUG: loadItem failed to resolve result from \(String(describing: type(of: item)))")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @MainActor
    func consume(urls: [URL]) async {
        print("DEBUG: consume started with \(urls.count) URLs")
        guard !urls.isEmpty else { return }

        // reset detailed list
        self.processedFiles.removeAll()
        self.isProcessing = true
        
        // Phase 1: Offload File Walking to Detached Task (Prevents UI Freeze)
        let uniqueFiles: [URL] = await Task.detached {
            let walker = FileWalker()
            var collected: [URL] = []
            for url in urls {
                let files = walker.enumerateSupportedFiles(at: url)
                collected.append(contentsOf: files)
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
            return unique
        }.value

        guard !uniqueFiles.isEmpty else { 
            self.isProcessing = false
            return 
        }
        
        // Populate initial list (Fast on Main Actor for N < 10000, acceptable)
        // For extremely large lists, this could also be lazy, but for <5000 it's fine.
        var initialList: [ProcessedFile] = []
        initialList.reserveCapacity(uniqueFiles.count)
        
        for fileURL in uniqueFiles {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let pFile = ProcessedFile(
                url: fileURL,
                originalSize: Int64(size),
                optimizedSize: 0,
                status: .pending
            )
            initialList.append(pFile)
        }
        self.processedFiles = initialList

        // Reset Stats
        stats.totalInBatch = uniqueFiles.count
        stats.totalFiles = uniqueFiles.count
        stats.processedFiles = 0
        stats.totalOriginalSize = 0
        stats.totalCompressedSize = 0
        stats.errorCount = 0
        stats.successfulFiles = 0
        stats.failedFiles = 0
        stats.skippedFiles = 0

        // Prepare Settings
        var settings = AppSettings()
        if let store = settingsStore {
            settings.preset = store.preset
            settings.saveMode = store.saveMode
            settings.preserveMetadata = store.preserveMetadata
            settings.convertToSRGB = store.convertToSRGB
            settings.enableGifsicle = store.enableGifsicle
            
            settings.customJpegQuality = store.customJpegQuality
            settings.customPngLevel = store.customPngLevel
            settings.customAvifQuality = store.customAvifQuality
            settings.customAvifSpeed = store.customAvifSpeed
        }
        
        let md = UserDefaults.standard.object(forKey: "settings.maxDimension") as? Double ?? 0
        settings.maxDimension = md > 0 ? Int(md) : nil

        // UI Throttling Helpers
        var lastUpdateTime: TimeInterval = 0
        let throttleInterval: TimeInterval = 0.15 // 150ms throttle
        
        SecureIntegrationLayer.shared.compressFiles(
            urls: uniqueFiles,
            settings: settings,
            progressCallback: { [weak self] processed, total, filename in
                guard let self = self else { return }
                
                // Throttle UI updates
                let now = Date().timeIntervalSinceReferenceDate
                if now - lastUpdateTime > throttleInterval || processed == total {
                    lastUpdateTime = now
                    
                    Task { @MainActor in
                        self.stats.processedFiles = processed
                        self.stats.totalInBatch = total
                        
                        if !filename.isEmpty {
                            self.currentFileName = NSLocalizedString("Обработка: ", comment: "") + filename
                            // OPTIMIZATION: Don't search full array for status update if list is huge
                            if self.processedFiles.count < 2000 {
                                if let index = self.processedFiles.firstIndex(where: { $0.url.lastPathComponent == filename }) {
                                    self.processedFiles[index].status = .processing
                                }
                            }
                        }
                    }
                }
            },
            completion: { [weak self] results in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    var successCount = 0
                    var skippedCount = 0
                    var failureCount = 0
                    var totalOriginal: Int64 = 0
                    var totalCompressed: Int64 = 0

                    // Create a map for O(1) lookups
                    var resultMap: [String: ProcessResult] = [:]
                    for result in results {
                         resultMap[result.originalPath] = result
                    }
                    
                    // Batch update processedFiles
                    // We map the existing array to a new one to trigger a single view update
                    var updatedFiles = self.processedFiles
                    
                    for i in 0..<updatedFiles.count {
                        let path = updatedFiles[i].url.path
                        if let result = resultMap[path] {
                            let status = result.status.lowercased()
                            let isSuccess = status == "success" || status == "ok"
                            let isSkipped = status == "skipped"
                            
                            updatedFiles[i].originalSize = result.originalSizeBytes
                            updatedFiles[i].optimizedSize = result.newSizeBytes
                            
                            if isSuccess {
                                updatedFiles[i].status = .done
                                successCount += 1
                                totalOriginal += result.originalSizeBytes
                                totalCompressed += result.newSizeBytes
                            } else if isSkipped {
                                updatedFiles[i].status = .skipped
                                skippedCount += 1
                            } else {
                                updatedFiles[i].status = .error
                                failureCount += 1
                            }
                        }
                    }
                    
                    // Single publish
                    self.processedFiles = updatedFiles

                    self.stats.successfulFiles = successCount
                    self.stats.skippedFiles = skippedCount
                    self.stats.failedFiles = failureCount
                    self.stats.processedFiles = successCount + skippedCount + failureCount
                    self.stats.totalOriginalSize = totalOriginal
                    self.stats.totalCompressedSize = totalCompressed
                    self.stats.errorCount = failureCount

                    self.isProcessing = false
                    AppUIManager.shared.showDockBounce()
                }
            }
        )
    }
    
    func cancelProcessing() {
        ProcessingManager.shared.cancel()
        SecureIntegrationLayer.shared.cancelCompression()
        self.isProcessing = false
    }
    
    // MARK: - Integration
    
    private var observers: [NSObjectProtocol] = []
    
    @MainActor
    func bindEvents() {
        let center = NotificationCenter.default
        
        let openFiles = center.addObserver(forName: .openFiles, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isProcessing else { return }
                self.pickFiles()
            }
        }
        observers.append(openFiles)
        
        let openFolder = center.addObserver(forName: .openFolder, object: nil, queue: .main) { [weak self] _ in
             Task { @MainActor in
                 guard let self = self, !self.isProcessing else { return }
                 self.pickFolder()
             }
        }
        observers.append(openFolder)
        
        let cancel = center.addObserver(forName: .cancelProcessing, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cancelProcessing() }
        }
        observers.append(cancel)
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
    
    deinit {
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
    }
}
