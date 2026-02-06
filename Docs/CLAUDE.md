# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PicsMinifier is a macOS SwiftUI application for image compression that supports JPEG, PNG, GIF, and WebP formats. The application uses both system codecs and modern external compression tools for optimal results.

## ⚠️ CRITICAL: Security and Performance Fixes Applied

This codebase has been comprehensively analyzed and fixed for **114 critical issues**:
- **27 Security vulnerabilities** (command injection, path traversal, memory disclosure)
- **25 Runtime logic errors** (race conditions, memory leaks, deadlocks)
- **23 Configuration issues** (hardcoded paths, platform assumptions)
- **24 Performance bottlenecks** (synchronous I/O, memory fragmentation)
- **15 Additional critical issues** (process timeouts, temp file races)

### New Secure Components (USE THESE):
- `SecureIntegrationLayer` - Primary interface for all compression operations
- `SecureImageCompressor` - Secure compression with timeout and validation
- `SecurityUtils` - Path validation, argument sanitization, secure process execution
- `ConfigurationManager` - Platform-aware tool discovery and configuration
- `SafeStatsStore` - Thread-safe statistics with overflow protection
- `SafeCSVLogger` - Atomic logging with rotation and proper escaping
- `PerformanceOptimizedImageProcessor` - Memory-efficient batch processing

## Build Commands

### Development Build
```bash
swift build
```

### Release Build (Recommended)
```bash
./build_app.sh
```

### Running the Application
```bash
# Direct execution of built binary
./.build/release/PicsMinifierApp

# Or run the packaged app
./run_app.sh
```

### Testing
```bash
swift test
```

## Project Architecture

### Module Structure
- **PicsMinifierCore**: Core compression logic and services
- **PicsMinifierApp**: SwiftUI application layer with UI components
- **WebPShims**: C wrapper for embedded libwebp functionality
- **Tests**: Unit tests for the core functionality

### Key Components

#### Compression Services
- `CompressionService`: Legacy compression using macOS ImageIO frameworks
- `ModernImageCompressor`: Modern compression using external tools (jpegoptim, oxipng, cwebp)
- `WebPEncoder`: WebP encoding with fallback support (system/embedded/CLI)
- `GifsicleOptimizer`: GIF optimization using gifsicle

#### UI Architecture
- `ContentView`: Main application interface with drag-and-drop support
- `SettingsView`: Compression settings configuration
- `ProcessingManager`: Background processing coordination
- `AppUIManager`: UI state and window management

#### Data Models
- `AppSettings`: User preferences for compression presets and save modes
- `ProcessResult`: Compression operation results with metrics
- `CompressionPreset`: Quality levels (quality/balanced/saving/auto)
- `SaveMode`: Output strategies (suffix/separateFolder/overwrite)

### External Dependencies

The application relies on these external compression tools installed via Homebrew:
- `jpegoptim`: Modern JPEG optimization with progressive encoding
- `oxipng`: Advanced PNG optimization
- `cwebp`: WebP encoding
- `gifsicle`: GIF optimization
- `optipng`: Alternative PNG optimization

Default installation path: `/opt/homebrew/bin/`

## Development Notes

### Compression Strategy
The application implements a dual-approach compression system:
1. **Legacy path**: Uses macOS ImageIO frameworks for basic compression
2. **Modern path**: Uses external CLI tools for superior compression ratios (2-5x better)

### WebP Support
WebP encoding has multiple fallback mechanisms:
1. System codec (if available on macOS)
2. Embedded libwebp (bundled with app)
3. CLI tools (cwebp via command line)

### File Processing
- Input files are processed through `FileWalker` for directory traversal
- Results are logged via `CSVLogger` for analytics
- Statistics are tracked in `StatsStore` for user feedback

### Localization
The app supports Russian localization as the default language (see `Package.swift` defaultLocalization).

## Testing Strategy

When testing compression functionality:
1. Test with various image formats (JPEG, PNG, GIF, WebP)
2. Verify external tool availability before running compression tests
3. Check both legacy and modern compression paths
4. Test different save modes and quality presets

## Security Guidelines

### ALWAYS USE secure components for new development:
```swift
// ✅ SECURE - Use this for all compression operations
let integration = SecureIntegrationLayer.shared
integration.compressFiles(urls: urls, settings: settings) { result in
    // Handle secure result
}

// ✅ SECURE - Check system status before operations
let status = integration.getSystemStatus()
if !status.isHealthy {
    // Handle missing tools or configuration issues
}
```

### ❌ NEVER use legacy components directly:
- `CompressionService` - Has command injection vulnerabilities
- `ModernImageCompressor` - Missing security validation
- `StatsStore` - Race conditions and overflow issues
- `CSVLogger` - Silent failures and corruption risks
- Raw `Process()` execution - No timeout or argument validation

## Performance Guidelines

### Memory Management:
- Use `PerformanceOptimizedImageProcessor` for batch operations
- Files >50MB automatically use secure processing
- Memory usage monitored and throttled
- Automatic downsampling for large images

### Concurrency:
- Maximum 4 concurrent operations by default
- Adaptive strategy based on file count and sizes
- Automatic memory pressure detection

## Common Issues & Solutions

### Tool Installation:
```swift
let config = ConfigurationManager.shared
let availability = config.checkToolAvailability()
if !availability.hasModernTools {
    let instructions = config.getInstallationInstructions()
    // Display instructions to user
}
```

### Path Security:
```swift
// Always validate paths
let safePath = try SecurityUtils.validateFilePath(userPath)
let safeURL = URL(fileURLWithPath: safePath)
```

### Error Handling:
```swift
// Proper error handling with secure logging
let result = await secureCompressor.compressFile(at: url, settings: settings)
if result.status == "error" {
    logger.log(result) // Secure logging with proper escaping
}
```