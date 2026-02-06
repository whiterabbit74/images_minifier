import SwiftUI
import PicsMinifierCore
import AppKit

struct SettingsView: View {
    @AppStorage("settings.preset") private var presetRaw: String = CompressionPreset.balanced.rawValue
    @AppStorage("settings.saveMode") private var saveModeRaw: String = SaveMode.suffix.rawValue
    @AppStorage("settings.preserveMetadata") private var preserveMetadata: Bool = true
    @AppStorage("settings.convertToSRGB") private var convertToSRGB: Bool = false
    @AppStorage("settings.enableGifsicle") private var enableGifsicle: Bool = true
    @AppStorage("settings.maxDimension") private var maxDimension: Double = 0
    @AppStorage("ui.appearanceMode") private var appearanceModeRaw: String = AppearanceMode.auto.rawValue
    @AppStorage("ui.showDockIcon") private var showDockIcon: Bool = true
    @AppStorage("ui.showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("ui.showOnlyWithGain") private var showOnlyWithGain: Bool = false
    @AppStorage("stats.disableStatistics") private var disableStatistics: Bool = false

    @State private var confirmOverwrite: Bool = false
    @State private var maxDimText: String = ""
    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = false
        return f
    }()



    private var interfaceMode: InterfaceMode {
        if showDockIcon && showMenuBarIcon { return .both }
        if showDockIcon { return .dock }
        return .menuBar // Default fallback if dock is off
    }

    private func setInterfaceMode(_ mode: InterfaceMode) {
        switch mode {
        case .dock:
            showDockIcon = true
            showMenuBarIcon = false
        case .both:
            showDockIcon = true
            showMenuBarIcon = true
        case .menuBar:
            showDockIcon = false
            showMenuBarIcon = true
        }
        
        // Apply changes immediately
        AppUIManager.shared.setDockIconVisible(showDockIcon)
        AppUIManager.shared.setMenuBarIconVisible(showMenuBarIcon)
        notify()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("Settings", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.top, 8)

                // 🎨 APPEARANCE
                GroupBox(label: Label(NSLocalizedString("Appearance", comment: ""), systemImage: "eye.fill")
                    .foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Appearance Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Appearance Mode", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: Binding(
                                get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .auto },
                                set: {
                                    appearanceModeRaw = $0.rawValue
                                    notify()
                                }
                            )) {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                    Text(NSLocalizedString("Light", comment: ""))
                                }.tag(AppearanceMode.light)

                                HStack {
                                    Image(systemName: "moon.fill")
                                    Text(NSLocalizedString("Dark", comment: ""))
                                }.tag(AppearanceMode.dark)

                                HStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                    Text(NSLocalizedString("System Default", comment: ""))
                                }.tag(AppearanceMode.auto)
                            }
                            .pickerStyle(.radioGroup)
                        }

                        Divider()

                        // Interface Mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("Interface Mode", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 0) {
                                // Dock Only
                                InterfaceModeButton(
                                    mode: .dock,
                                    current: interfaceMode,
                                    icon: "dock.rectangle",
                                    title: NSLocalizedString("Dock", comment: "")
                                ) {
                                    setInterfaceMode(.dock)
                                }

                                Divider()
                                    .frame(height: 40)

                                // Both
                                InterfaceModeButton(
                                    mode: .both,
                                    current: interfaceMode,
                                    icon: "macwindow.on.rectangle",
                                    title: NSLocalizedString("Both", comment: "")
                                ) {
                                    setInterfaceMode(.both)
                                }

                                Divider()
                                    .frame(height: 40)

                                // Menu Bar Only
                                InterfaceModeButton(
                                    mode: .menuBar,
                                    current: interfaceMode,
                                    icon: "menubar.rectangle",
                                    title: NSLocalizedString("Menu Bar", comment: "")
                                ) {
                                    setInterfaceMode(.menuBar)
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Show only with savings
                        HStack {
                            Toggle(NSLocalizedString("Show only with savings", comment: ""), isOn: $showOnlyWithGain)
                                .onChange(of: showOnlyWithGain) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }
                    }
                    .padding(12)
                }

                // 🔧 COMPRESSION QUALITY
                GroupBox(label: Label(NSLocalizedString("Compression Quality", comment: ""), systemImage: "wand.and.stars")
                    .foregroundColor(.green)) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("Compression Preset", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: Binding(
                                get: { CompressionPreset(rawValue: presetRaw) ?? .balanced },
                                set: { presetRaw = $0.rawValue; notify() }
                            )) {
                                HStack {
                                    Image(systemName: "star.fill")
                                    Text(NSLocalizedString("Maximum Quality", comment: ""))
                                }.tag(CompressionPreset.quality)

                                HStack {
                                    Image(systemName: "circle.fill")
                                    Text(NSLocalizedString("Balanced", comment: ""))
                                }.tag(CompressionPreset.balanced)

                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text(NSLocalizedString("Maximum Savings", comment: ""))
                                }.tag(CompressionPreset.saving)

                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text(NSLocalizedString("Automatic", comment: ""))
                                }.tag(CompressionPreset.auto)
                            }
                            .pickerStyle(.radioGroup)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("File Save Mode", comment: ""))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: Binding(
                                get: { SaveMode(rawValue: saveModeRaw) ?? .suffix },
                                set: { newValue in
                                    if newValue == .overwrite {
                                        confirmOverwrite = true
                                    } else {
                                        saveModeRaw = newValue.rawValue
                                        notify()
                                    }
                                }
                            )) {
                                HStack {
                                    Image(systemName: "plus.rectangle.fill")
                                    Text(NSLocalizedString("Add suffix '_compressed'", comment: ""))
                                }.tag(SaveMode.suffix)

                                HStack {
                                    Image(systemName: "folder.fill")
                                    Text(NSLocalizedString("Create 'Compressor' folder", comment: ""))
                                }.tag(SaveMode.separateFolder)

                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(NSLocalizedString("Overwrite originals", comment: ""))
                                }.tag(SaveMode.overwrite)
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                    .padding(12)
                }

                // 📏 IMAGE DIMENSIONS
                GroupBox(label: Label(NSLocalizedString("Image Dimensions", comment: ""), systemImage: "rectangle.resize")
                    .foregroundColor(.purple)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Max dimension
                        HStack {
                            Text(NSLocalizedString("Max side dimension", comment: ""))
                        Spacer()
                        }

                        HStack(spacing: 12) {
                            TextField("", text: $maxDimText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                                .onChange(of: maxDimText) { _ in applyMaxDimText() }

                            Text(NSLocalizedString("pixels", comment: ""))
                                .foregroundColor(.secondary)

                            Spacer()

                            if maxDimension == 0 {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(NSLocalizedString("No limits", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "arrow.down.right.circle.fill")
                                        .foregroundColor(.orange)
                                    Text(NSLocalizedString("Dimension limited", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        Text(NSLocalizedString("0 — no dimension limit", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()

                        Divider()

                        // Metadata
                        HStack {
                            Toggle(NSLocalizedString("Preserve metadata", comment: ""), isOn: $preserveMetadata)
                                .onChange(of: preserveMetadata) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }

                        HStack {
                            Toggle(NSLocalizedString("Convert to sRGB", comment: ""), isOn: $convertToSRGB)
                                .onChange(of: convertToSRGB) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }

                        HStack {
                            Toggle(NSLocalizedString("Optimize GIF", comment: ""), isOn: $enableGifsicle)
                                .onChange(of: enableGifsicle) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }
                    }
                    .padding(12)
                }

                // 📊 STATISTICS
                GroupBox(label: Label("Statistics", systemImage: "chart.bar.fill")
                    .foregroundColor(.orange)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(format: NSLocalizedString("Files processed: %lld", comment: ""), StatsStore.shared.allTimeProcessedCount))
                                    .font(.headline)
                                Text(String(format: NSLocalizedString("Total saved: %@", comment: ""), ByteCountFormatter.string(fromByteCount: StatsStore.shared.allTimeSavedBytes, countStyle: .file)))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }

                        Divider()

                        HStack {
                            Toggle(NSLocalizedString("Disable statistics", comment: ""), isOn: $disableStatistics)
                                .toggleStyle(.switch)
                            Spacer()
                        }
                        
                        Text(NSLocalizedString("When disabled, compression data is not saved.", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                resetStatsAndLogs()
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text(NSLocalizedString("Reset Statistics", comment: ""))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                }

                // 📁 SUPPORTED FORMATS
                GroupBox(label: Label(NSLocalizedString("Supported Formats", comment: ""), systemImage: "doc.badge.gearshape.fill")
                    .foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("Libraries used for file processing", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(alignment: .leading, spacing: 8) {
                            FormatProcessorRow(
                                extensions: ["jpg", "jpeg"],
                                icon: "photo.fill",
                                color: .orange,
                                processor: jpegProcessorName(),
                                description: jpegProcessorDescription(),
                                hasOptions: jpegHasOptions()
                            )

                            FormatProcessorRow(
                                extensions: ["png"],
                                icon: "photo.on.rectangle.fill",
                                color: .blue,
                                processor: pngProcessorName(),
                                description: pngProcessorDescription(),
                                hasOptions: pngHasOptions()
                            )

                            FormatProcessorRow(
                                extensions: ["heic", "heif"],
                                icon: "camera.fill",
                                color: .purple,
                                processor: "ImageIO (macOS)",
                                description: "System HEIF codec",
                                hasOptions: false
                            )

                            FormatProcessorRow(
                                extensions: ["webp"],
                                icon: "globe.central.south.asia.fill",
                                color: .green,
                                processor: webpProcessorName(),
                                description: webpProcessorDescription(),
                                hasOptions: webpHasOptions()
                            )

                            FormatProcessorRow(
                                extensions: ["gif"],
                                icon: "film.fill",
                                color: .red,
                                processor: gifProcessorName(),
                                description: gifProcessorDescription(),
                                hasOptions: gifHasOptions()
                            )

                            FormatProcessorRow(
                                extensions: ["tiff"],
                                icon: "doc.richtext.fill",
                                color: .brown,
                                processor: "ImageIO (macOS)",
                                description: "System TIFF codec with LZW",
                                hasOptions: false
                            )
                        }

                        // Info about improvements
                        if needsModernTools() {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                    Text(NSLocalizedString("Improve compression!", comment: ""))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    if !jpegHasOptions() {
                                        Text(NSLocalizedString("• JPEG: install MozJPEG for +35% better compression", comment: ""))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !pngHasOptions() {
                                        Text(NSLocalizedString("• PNG: install Oxipng for +20% better compression", comment: ""))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !gifHasOptions() {
                                        Text(NSLocalizedString("• GIF: install Giflossy for +30% better compression", comment: ""))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack {
                                    Text(NSLocalizedString("Command: brew install mozjpeg oxipng giflossy", comment: ""))
                                        .font(.caption2)
                                        .fontFamily(.monospaced)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                }

                // 🔍 TOOLS & DIAGNOSTICS
                GroupBox(label: Label(NSLocalizedString("Tools", comment: ""), systemImage: "wrench.and.screwdriver.fill")
                    .foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("Check tool availability", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            Button {
                                let availability = WebPEncoder().availability()
                                var msg = ""
                                switch availability {
                                case .systemCodec: msg = NSLocalizedString("✅ System WebP codec available", comment: "")
                                case .embedded: msg = NSLocalizedString("✅ Embedded WebP available", comment: "")
                                case .unavailable: msg = NSLocalizedString("❌ WebP unavailable", comment: "")
                                }
                                showInfoAlert(title: "WebP", message: msg)
                            } label: {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text(NSLocalizedString("WebP", comment: ""))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                let fm = FileManager.default
                                var found: String = ""
                                if let url = Bundle.module.url(forResource: "gifsicle", withExtension: nil), fm.isExecutableFile(atPath: url.path) {
                                    found = url.path
                                } else if let url = Bundle.main.url(forResource: "gifsicle", withExtension: nil), fm.isExecutableFile(atPath: url.path) {
                                    found = url.path
                                } else if fm.isExecutableFile(atPath: "/opt/homebrew/bin/gifsicle") {
                                    found = "/opt/homebrew/bin/gifsicle"
                                } else if fm.isExecutableFile(atPath: "/usr/local/bin/gifsicle") {
                                    found = "/usr/local/bin/gifsicle"
                                }
                                let msg = found.isEmpty ? NSLocalizedString("❌ gifsicle not found", comment: "") : String(format: NSLocalizedString("✅ gifsicle: %@", comment: ""), found)
                                showInfoAlert(title: "gifsicle", message: msg)
                            } label: {
                                HStack {
                                    Image(systemName: "film.fill")
                                    Text(NSLocalizedString("GIF", comment: ""))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }

                        Divider()

                        DisclosureGroup(NSLocalizedString("Advanced", comment: "")) {
                            HStack(spacing: 12) {
                                Button {
                                    NSWorkspace.shared.open(AppPaths.logCSVURL())
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text(NSLocalizedString("CSV Log", comment: ""))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([AppPaths.logsDirectory()])
                                } label: {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                        Text(NSLocalizedString("Logs Folder", comment: ""))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .padding(20)
        }
        .frame(width: 580, height: 520)
        .alert(NSLocalizedString("Overwrite Originals", comment: ""), isPresented: $confirmOverwrite) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("Continue", comment: ""), role: .destructive) {
                saveModeRaw = SaveMode.overwrite.rawValue
                notify()
            }
        } message: {
            Text(NSLocalizedString("Files will be overwritten irrecoverably. Are you sure?", comment: ""))
        }
        .onAppear {
            AppUIManager.shared.setDockIconVisible(showDockIcon)
            AppUIManager.shared.setMenuBarIconVisible(showMenuBarIcon)
            maxDimText = maxDimension > 0 ? String(Int(maxDimension)) : "0"
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    private func applyMaxDimText() {
        let filtered = maxDimText.filter { $0.isNumber }
        if filtered != maxDimText { maxDimText = filtered }
        let value = Int(filtered) ?? 0
        let v = max(0, value)
        let prev = Int(maxDimension)
        if prev != v {
            maxDimension = Double(v)
            notify()
        }
    }

    private func resetStatsAndLogs() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Reset statistics?", comment: "")
        alert.informativeText = NSLocalizedString("Counters will be reset and CSV log deleted. This action is irreversible.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Reset", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            StatsStore.shared.resetAll()
            let url = AppPaths.logCSVURL()
            try? FileManager.default.removeItem(at: url)
            _ = CSVLogger(logURL: url) // recreate with header
            notify()
        }
    }

    private func webpProcessorName() -> String {
        let encoder = WebPEncoder()
        switch encoder.availability() {
        case .systemCodec: return "ImageIO (macOS)"
        case .embedded: return "libwebp (Embedded)"
        case .unavailable: return "Unavailable"
        }
    }

    private func webpProcessorDescription() -> String {
        let encoder = WebPEncoder()
        switch encoder.availability() {
        case .systemCodec: return "System WebP codec"
        case .embedded: return "Embedded libwebp library"
        case .unavailable: return "WebP codec not found"
        }
    }

    private func webpHasOptions() -> Bool {
        let encoder = WebPEncoder()
        return encoder.availability() != .unavailable
    }

    private func gifsicleStatus() -> String {
        let modernGif = ModernGifOptimizer()
        let tools = modernGif.getAvailableTools()
        return tools.isEmpty ? "Not found" : tools.first ?? "Not found"
    }

    // New methods for modern compressors
    private func jpegProcessorName() -> String {
        let mozjpeg = MozJPEGCompressor()
        return mozjpeg.isAvailable() ? "MozJPEG" : "ImageIO (macOS)"
    }

    private func jpegProcessorDescription() -> String {
        let mozjpeg = MozJPEGCompressor()
        return mozjpeg.isAvailable() ? "Modern JPEG optimizer (+35% compression)" : "System JPEG codec"
    }

    private func pngProcessorName() -> String {
        let oxipng = OxipngCompressor()
        return oxipng.isAvailable() ? "Oxipng" : "ImageIO (macOS)"
    }

    private func pngProcessorDescription() -> String {
        let oxipng = OxipngCompressor()
        return oxipng.isAvailable() ? "Fast PNG optimizer (+20% compression)" : "System PNG codec"
    }

    private func jpegHasOptions() -> Bool {
        let mozjpeg = MozJPEGCompressor()
        return mozjpeg.isAvailable()
    }

    private func pngHasOptions() -> Bool {
        let oxipng = OxipngCompressor()
        return oxipng.isAvailable()
    }

    private func gifProcessorName() -> String {
        let modernGif = ModernGifOptimizer()
        let tools = modernGif.getAvailableTools()
        if tools.contains(where: { $0.contains("Giflossy") }) {
            return "Giflossy + Gifsicle"
        } else if tools.contains(where: { $0.contains("Gifsicle") }) {
            return "Gifsicle"
        } else {
            return "Not found"
        }
    }

    private func gifProcessorDescription() -> String {
        let modernGif = ModernGifOptimizer()
        let tools = modernGif.getAvailableTools()
        if tools.contains(where: { $0.contains("Giflossy") }) {
            return "Advanced GIF optimizer (+30% compression)"
        } else if tools.contains(where: { $0.contains("Gifsicle") }) {
            return "Basic GIF optimizer"
        } else {
            return "Optimizer not found"
        }
    }

    private func gifHasOptions() -> Bool {
        let modernGif = ModernGifOptimizer()
        return modernGif.isAvailable()
    }

    private func needsModernTools() -> Bool {
        return !jpegHasOptions() || !pngHasOptions() || !gifHasOptions()
    }

    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

struct FormatProcessorRow: View {
    let extensions: [String]
    let icon: String
    let color: Color
    let processor: String
    let description: String
    let hasOptions: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Format icon
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            // Extensions
            HStack(spacing: 4) {
                ForEach(extensions, id: \.self) { ext in
                    Text(".\(ext.uppercased())")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .frame(width: 120, alignment: .leading)

            // Separator
            Text("→")
                .foregroundColor(.secondary)

            // Processor Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(processor)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if hasOptions {
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption2)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}


