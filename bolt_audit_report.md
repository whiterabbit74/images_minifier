## ⚡ Bolt Performance Audit

**Date:** 2026-02-05
**Status:** 4 Major Bottlenecks Identified

### 1. Main Thread Flooding (Critical)
**Location:** `Sources/PicsMinifierApp/ProcessingManager.swift`
**Issue:**
When processing a batch of files, the application dispatches UI updates to the Main Thread for *every single file completion*:
```swift
DispatchQueue.main.async {
    NSApp.dockTile.badgeLabel = "✓"
    AppUIManager.shared.showDockBounce()
}
```
**Impact:**
- "Thundering Herd" effect on the Main Thread.
- UI freezes/jank during large batches (e.g., 1000+ images).
- Unnecessary drawing cycles for updates the user can't see (faster than refresh rate).

**Optimization:**
- **Throttle/Debounce:** Only update UI every 100ms or every N files (e.g., every 1% progress).
- **Batch updates:** Use a `CADisplayLink` or `Timer` to pull progress from a shared atomic counter instead of pushing updates.

### 2. CSV Logger File Handle Churn (High)
**Location:** `Sources/PicsMinifierCore/CSVLogger.swift`
**Issue:**
The logger opens, seeks, writes, and closes the log file for *every single record*:
```swift
let fileHandle = try FileHandle(forWritingTo: self.logURL)
defer { fileHandle.closeFile() }
```
**Impact:**
- Massive syscall overhead (open/close) during batch processing.
- increased disk I/O latency.
- Potential file locking contention.

**Optimization:**
- Keep the `FileHandle` open for the lifecycle of the `CSVLogger`.
- Implement a buffered writer (flush every N records or T timeframe).

### 3. NotificationCenter Spam (Medium)
**Location:** `Sources/PicsMinifierApp/ProcessingManager.swift`
**Issue:**
Posts a `.processingResult` notification for every file.
```swift
NotificationCenter.default.post(name: .processingResult, object: result)
```
**Impact:**
- Triggers all observers (likely UI refresh logic) synchronously on the posting thread (or main thread if dispatched).
- Increases CPU usage linearly with batch size.

**Optimization:**
- Batch notifications or use `@Published` / `ObservableObject` properties with throttled Combine pipelines for UI updates.

### 4. Process Spawning Overhead (High, Architectural)
**Location:** `Sources/PicsMinifierCore/SmartCompressor.swift`
**Issue:**
A new shell process (`Process()`) is spawned for every single file to run `mozjpeg`, `oxipng`, etc.
**Impact:**
- Significant overhead (fork/exec) compared to using a library (C-API).
- Limits maximum throughput for small files.

**Optimization:**
- **Short term:** None (requires using C libraries like `libjpeg-turbo` directly via Swift/C interop instead of CLI tools).
- **Mitigation:** Ensure `maxConcurrent` is tuned (currently `processorCount - 1`).

---

### bolt_recommendation
**Priority Fix:** Throttle UI updates in `ProcessingManager.swift`. This provides the most visible performance improvement for the user with minimal code change.
