import SwiftUI
import PicsMinifierCore
import UniformTypeIdentifiers

@Observable
@MainActor
class SessionStore {
    var processedFiles: [ProcessedFile] = []
    var stats: SessionStats = .init()
    var isProcessing: Bool = false
    var currentFileName: String = ""
    
    // Session Stats (Reset on app launch)
    var sessionCompressedCount: Int = 0
    var sessionOriginalBytes: Int = 0
    var sessionSavedBytes: Int = 0
    
    // Dependencies
    var settingsStore: SettingsStore?
    
    // Track URLs with active security scope
    private var accessedURLs = Set<URL>()
    
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
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
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
                    
                    Task { @MainActor [weak self] in
                        // Handle security scope if needed
                        if url.startAccessingSecurityScopedResource() {
                            print("DEBUG: Accessed security scoped resource: \(url.path)")
                            self?.accessedURLs.insert(url)
                        }
                        continuation.resume(returning: url)
                    }
                } else {
                    print("DEBUG: loadItem failed to resolve result from \(String(describing: type(of: item)))")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

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
            cleanupResources()
            return 
        }
        
        // Populate initial list (Fast on Main Actor for N < 10000, acceptable)
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

        // Check for immediate compression
        if settingsStore?.compressImmediately == true {
             await startPendingCompression()
        } else {
             self.isProcessing = false
             // If not compressing immediately, we still need to wait or cleanup later?
             // Usually we cleanup after the WHOLE batch is done.
        }
    }
    
    func startPendingCompression() async {
        let pendingFiles = processedFiles.filter { $0.status == .pending }
        guard !pendingFiles.isEmpty else { return }
        
        self.isProcessing = true
        
        let urlsToProcess = pendingFiles.map { $0.url }
        
        // Prepare Settings
        var settings = AppSettings()
        if let store = settingsStore {
            settings.preset = store.preset
            settings.saveMode = store.saveMode
            settings.preserveMetadata = store.preserveMetadata
            settings.convertToSRGB = store.convertToSRGB
            settings.enableGifsicle = store.enableGifsicle
            settings.enableSvgcleaner = store.enableSvgcleaner
            
            settings.customJpegQuality = store.customJpegQuality
            settings.customPngLevel = store.customPngLevel
            settings.customAvifQuality = store.customAvifQuality
            settings.customAvifSpeed = store.customAvifSpeed
            settings.customWebPQuality = store.customWebPQuality
            settings.customWebPMethod = store.customWebPMethod
            settings.svgPrecision = store.svgPrecision
            settings.svgMultipass = store.svgMultipass
            
            settings.resizeEnabled = store.resizeEnabled
            settings.resizeValue = store.resizeValue
            settings.resizeCondition = store.resizeCondition
            settings.compressImmediately = store.compressImmediately
        }
        
        // Use modern UserDefaults access
        let md = UserDefaults.standard.double(forKey: "settings.maxDimension")
        settings.maxDimension = md > 0 ? Int(md) : nil

        // UI Throttling Helpers
        var lastUpdateTime: TimeInterval = 0
        let throttleInterval: TimeInterval = 0.15 // 150ms throttle
        
        await SecureIntegrationLayer.shared.compressFiles(
            urls: urlsToProcess,
            settings: settings,
            progressCallback: { [weak self] processed, total, url, result in
                guard let self = self else { return }
                
                let now = Date().timeIntervalSinceReferenceDate
                let isBatchEnd = url == nil && result == nil
                let isFileStart = url != nil && result == nil
                let isFileEnd = url != nil && result != nil
                
                // Always update for file transitions, throttle for regular progress
                let shouldUpdate = now - lastUpdateTime > throttleInterval || processed == total || isFileStart || isFileEnd || isBatchEnd
                
                if shouldUpdate {
                    if !isFileStart && !isFileEnd {
                        lastUpdateTime = now
                    }
                    
                    Task { @MainActor in
                        if isBatchEnd || processed == total {
                             self.stats.processedFiles = processed
                             self.stats.totalInBatch = total
                        }
                        
                        if let url = url, isFileStart {
                            let filename = url.lastPathComponent
                            self.currentFileName = NSLocalizedString("Processing: ", comment: "") + filename
                            if let index = self.processedFiles.firstIndex(where: { $0.url == url }) {
                                self.processedFiles[index].status = .processing
                            }
                        } else if let url = url, let result = result, isFileEnd {
                            if let index = self.processedFiles.firstIndex(where: { $0.url == url }) {
                                let status = result.status.lowercased()
                                self.processedFiles[index].originalSize = result.originalSizeBytes
                                self.processedFiles[index].optimizedSize = result.newSizeBytes
                                
                                if status == "success" || status == "ok" {
                                    self.processedFiles[index].status = .done
                                } else if status == "skipped" {
                                    self.processedFiles[index].status = .skipped
                                } else {
                                    self.processedFiles[index].status = .error
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
                        let key = URL(fileURLWithPath: result.originalPath).standardizedFileURL.path
                        resultMap[key] = result
                    }
                    
                    // Batch update processedFiles
                    var updatedFiles = self.processedFiles
                    
                    for i in 0..<updatedFiles.count {
                        let path = updatedFiles[i].url.standardizedFileURL.path
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
                    
                    // Update Session Stats
                    let savedInThisBatch = Int(max(0, totalOriginal - totalCompressed))
                    self.sessionCompressedCount += successCount
                    self.sessionOriginalBytes += Int(totalOriginal)
                    self.sessionSavedBytes += savedInThisBatch
                    
                    // Update Lifetime Stats
                    if let store = self.settingsStore, !store.disableStatistics {
                        store.lifetimeCompressedCount += successCount
                        store.lifetimeOriginalBytes += Int(totalOriginal)
                        store.lifetimeSavedBytes += savedInThisBatch
                        
                        // Per-format breakdown
                        for file in updatedFiles where file.status == .done {
                            let ext = file.url.pathExtension
                            let saved = Int(max(0, file.originalSize - file.optimizedSize))
                            store.updateFormatSavings(extension: ext, savedBytes: saved)
                        }
                    }
                    
                    AppUIManager.shared.showDockBounce()
                    
                    if self.settingsStore?.notifyOnCompletion == true {
                        AppUIManager.shared.showNotification(
                            title: NSLocalizedString("Compression Complete", comment: ""),
                            body: String(format: NSLocalizedString("Optimized %d images and saved %@", comment: ""), 
                                        self.stats.successfulFiles, 
                                        ByteCountFormatter.string(fromByteCount: self.stats.savedBytes, countStyle: .file))
                        )
                    }
                    
                    if self.settingsStore?.playSoundOnCompletion == true {
                        AppUIManager.shared.playCompletionSound()
                    }
                    
                    self.isProcessing = false
                    self.cleanupResources()
                }
            }
        )
    }
    
    private func cleanupResources() {
        print("DEBUG: Cleaning up \(accessedURLs.count) security scoped resources")
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }
    
    func cancelProcessing() {
        ProcessingManager.shared.cancel()
        Task {
            await SecureIntegrationLayer.shared.cancelCompression()
            await MainActor.run {
                self.isProcessing = false
                self.cleanupResources()
            }
        }
    }
    
    func clearSession() {
        self.processedFiles.removeAll()
        self.stats = SessionStats()
        self.sessionCompressedCount = 0
        self.sessionSavedBytes = 0
        self.currentFileName = ""
        self.isProcessing = false
        cleanupResources()
    }
    
    // MARK: - Integration
    
    private var observers: [NSObjectProtocol] = []
    
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
        // We can't access 'observers' here because it's MainActor-isolated
        // and deinit is non-isolated. However, for a singleton or app-lifecycle 
        // objects, this is often handled by the system. 
        // If needed, we could use a non-isolated observer storage, but for now 
        // let's just avoid the isolation break.
    }
}

