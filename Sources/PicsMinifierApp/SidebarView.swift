import SwiftUI
import PicsMinifierCore

struct SidebarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.colorScheme) var colorScheme
    @State private var hoverInfo: String = ""
    @State private var isShowingSavePresetAlert = false
    @State private var newPresetName = ""
    @State private var showRestartHint = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // PRESETS
                    SidebarGroup(title: NSLocalizedString("PRESETS", comment: "")) {
                        VStack(spacing: 0) {
                            // Main Preset
                            SidebarOptionRow(title: NSLocalizedString("Preset", comment: ""), hint: NSLocalizedString("Balanced (recommended) is the best mix of size and quality. Quality prioritizes details. Saving aggressively reduces size.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach(CompressionPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                                        Button(NSLocalizedString(preset.rawValue.capitalized, comment: "")) { settingsStore.preset = preset }
                                    }
                                    
                                    if !settingsStore.userPresets.isEmpty {
                                        Divider()
                                        ForEach(settingsStore.userPresets) { preset in
                                            Button(preset.name) { settingsStore.applyUserPreset(preset) }
                                        }
                                    }
                                } label: {
                                    Text(currentPresetName)
                                }
                            }

                            // Save Button
                            SidebarOptionRow(title: NSLocalizedString("Save Preset", comment: ""), hint: NSLocalizedString("Save current configuration as a named preset.", comment: ""), onHover: updateHover) {
                                Button(action: { isShowingSavePresetAlert = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bookmark.fill")
                                        Text(NSLocalizedString("Save", comment: ""))
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            .alert(NSLocalizedString("Save Preset", comment: ""), isPresented: $isShowingSavePresetAlert) {
                                TextField(NSLocalizedString("My Custom Preset", comment: ""), text: $newPresetName)
                                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) { newPresetName = "" }
                                Button(NSLocalizedString("Save", comment: ""), action: savePresetAndClose)
                            } message: {
                                Text(NSLocalizedString("Save current configuration as:", comment: ""))
                            }
                        }
                    }

                    // SETTINGS
                    SidebarGroup(title: NSLocalizedString("GENERAL", comment: "")) {
                        VStack(spacing: 0) {
                            // JPEG Quality
                            SidebarOptionRow(title: NSLocalizedString("JPEG Quality", comment: ""), hint: NSLocalizedString("Higher = better detail, larger files. 82–90% is the usual sweet spot on modern photos.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([0.6, 0.7, 0.8, 0.82, 0.85, 0.9, 0.95], id: \.self) { q in
                                        Button("\(Int(q * 100))%") { settingsStore.customJpegQuality = q }
                                    }
                                } label: {
                                    Text("\(Int(settingsStore.customJpegQuality * 100))%")
                                }
                            }

                            // PNG Compression
                            SidebarOptionRow(title: NSLocalizedString("PNG Level", comment: ""), hint: NSLocalizedString("Lossless. Higher levels take longer but shrink more. On Apple Silicon you can safely use 4–6.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([1, 2, 3, 4, 6, 9], id: \.self) { level in
                                        Button("Level \(level)") { settingsStore.customPngLevel = level }
                                    }
                                } label: {
                                    Text("Level \(settingsStore.customPngLevel)")
                                }
                            }

                            // AVIF Size
                            SidebarOptionRow(title: NSLocalizedString("AVIF Size", comment: ""), hint: NSLocalizedString("Lower values = higher quality and larger files. 20–30 is a good balance.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([15, 20, 25, 28, 30, 35, 45, 55], id: \.self) { q in
                                        Button("Level \(q)") { settingsStore.customAvifQuality = q }
                                    }
                                } label: {
                                    Text("Level \(settingsStore.customAvifQuality)")
                                }
                            }
                            
                            // AVIF Effort
                            SidebarOptionRow(title: NSLocalizedString("AVIF Effort", comment: ""), hint: NSLocalizedString("0 is slowest/smallest, 10 is fastest/largest. On powerful Macs, 2–4 is a good default.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([0, 2, 3, 4, 6, 8, 10], id: \.self) { s in
                                        Button("Speed \(s)") { settingsStore.customAvifSpeed = s }
                                    }
                                } label: {
                                    Text("Effort \(settingsStore.customAvifSpeed)")
                                }
                            }

                            // WebP Quality
                            SidebarOptionRow(title: NSLocalizedString("WebP Quality", comment: ""), hint: NSLocalizedString("Higher = better detail, larger files. 82–90 is a strong balance.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([70, 75, 80, 82, 85, 88, 90, 95], id: \.self) { q in
                                        Button("Q\(q)") { settingsStore.customWebPQuality = q }
                                    }
                                } label: {
                                    Text("Q\(settingsStore.customWebPQuality)")
                                }
                            }

                            // WebP Effort
                            SidebarOptionRow(title: NSLocalizedString("WebP Effort", comment: ""), hint: NSLocalizedString("0–6. Higher is smaller but slower. 5–6 is fine on Apple Silicon.", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach([0, 2, 3, 4, 5, 6], id: \.self) { m in
                                        Button("Effort \(m)") { settingsStore.customWebPMethod = m }
                                    }
                                } label: {
                                    Text("Effort \(settingsStore.customWebPMethod)")
                                }
                            }
                            
                            // GIF Lossy
                            SidebarOptionRow(title: NSLocalizedString("GIF Mode", comment: ""), hint: NSLocalizedString("Lossy can cut size drastically by simplifying colors. Lossless keeps every pixel but stays large.", comment: ""), onHover: updateHover) {
                                Menu {
                                    Button(NSLocalizedString("Lossy (Gifsicle)", comment: "")) { settingsStore.enableGifsicle = true }
                                    Button(NSLocalizedString("Lossless", comment: "")) { settingsStore.enableGifsicle = false }
                                } label: {
                                    Text(settingsStore.enableGifsicle ? NSLocalizedString("Lossy (Gifsicle)", comment: "") : NSLocalizedString("Lossless", comment: ""))
                                }
                            }
                            
                            // GIF Lossy Detail
                            SidebarOptionRow(title: NSLocalizedString("GIF Extra Lossy", comment: ""), hint: NSLocalizedString("Stronger lossy pass for GIFs. Requires Gifsicle.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.enableGifLossy)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                                    .disabled(!settingsStore.enableGifsicle)
                                    .opacity(settingsStore.enableGifsicle ? 1.0 : 0.4)
                            }

                            // SVG Cleaner
                            SidebarOptionRow(title: NSLocalizedString("SVG Cleaner", comment: ""), hint: NSLocalizedString("Optimize SVGs with svgcleaner. Disable to keep originals untouched.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.enableSvgcleaner)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }

                            // SVG Level
                            SidebarOptionRow(title: NSLocalizedString("SVG Level", comment: ""), hint: NSLocalizedString("Stronger levels reduce size more, with slightly higher simplification risk.", comment: ""), onHover: updateHover) {
                                Menu {
                                    Button(NSLocalizedString("Safe", comment: "")) { setSvgLevel(.safe) }
                                    Button(NSLocalizedString("Balanced", comment: "")) { setSvgLevel(.balanced) }
                                    Button(NSLocalizedString("Max", comment: "")) { setSvgLevel(.max) }
                                } label: {
                                    Text(svgLevelLabel)
                                }
                            }
                            
                        }
                    }

                    // RESIZING
                    SidebarGroup(title: NSLocalizedString("RESIZE", comment: "")) {
                        VStack(spacing: 0) {
                            // Toggle
                            SidebarOptionRow(title: NSLocalizedString("Resize Images", comment: ""), hint: NSLocalizedString("Shrink images to a specific size before compressing. Great for web or thumbnails.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.resizeEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }
                            
                            if settingsStore.resizeEnabled {
                                // Preset Picker
                                SidebarOptionRow(title: NSLocalizedString("Target Size", comment: ""), hint: NSLocalizedString("Choose a standard size or enter a custom value.", comment: ""), onHover: updateHover) {
                                    HStack(spacing: 4) {
                                        TextField(NSLocalizedString("Px", comment: ""), value: $settingsStore.resizeValue, formatter: NumberFormatter())
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        Menu {
                                            Text(NSLocalizedString("Common Sizes", comment: ""))
                                            Button("4096 (4K)") { settingsStore.resizeValue = 4096 }
                                            Button("1920 (HD)") { settingsStore.resizeValue = 1920 }
                                            Button("1280 (Web)") { settingsStore.resizeValue = 1280 }
                                            Button("1024") { settingsStore.resizeValue = 1024 }
                                            Button("800") { settingsStore.resizeValue = 800 }
                                        } label: {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .frame(width: 16, height: 16)
                                                .background(Color.black.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .menuStyle(.borderlessButton)
                                        .frame(width: 16)
                                    }
                                }
                                
                                // Condition Picker
                                SidebarOptionRow(title: NSLocalizedString("Mode", comment: ""), hint: NSLocalizedString("'Fit' keeps the aspect ratio within the box. 'Width'/'Height' enforce that dimension.", comment: ""), onHover: updateHover) {
                                    Menu {
                                        Button(NSLocalizedString("Fit (Longest Edge)", comment: "")) { settingsStore.resizeCondition = .fit }
                                        Button(NSLocalizedString("Width", comment: "")) { settingsStore.resizeCondition = .width }
                                        Button(NSLocalizedString("Height", comment: "")) { settingsStore.resizeCondition = .height }
                                    } label: {
                                        Text(settingsStore.resizeCondition.rawValue.capitalized)
                                    }
                                }
                            }
                        }
                    }

                    // WORKFLOW
                    SidebarGroup(title: NSLocalizedString("WORKFLOW", comment: "")) {
                        VStack(spacing: 0) {
                            SidebarOptionRow(title: NSLocalizedString("Direct Save", comment: ""), hint: NSLocalizedString("Start compressing files immediately after dropping them. Disable to review list first.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.compressImmediately)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }
                            
                            SidebarOptionRow(title: NSLocalizedString("Keep Metadata", comment: ""), hint: NSLocalizedString("Preserve EXIF, GPS, and creation dates. Increases file size slightly. Turn off for maximum privacy/saving.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.preserveMetadata)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }

                             SidebarOptionRow(title: NSLocalizedString("Convert to sRGB", comment: ""), hint: NSLocalizedString("Standardizes color profile for maximum web compatibility. Fixes 'washed out' colors in some browsers.", comment: ""), onHover: updateHover) {
                                Toggle("", isOn: $settingsStore.convertToSRGB)
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                                    .labelsHidden()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    
                    // OUTPUT
                    SidebarGroup(title: NSLocalizedString("OUTPUT", comment: "")) {
                        VStack(spacing: 0) {
                            SidebarOptionRow(title: NSLocalizedString("Mode", comment: ""), hint: NSLocalizedString("Where files go: 'Suffix' adds _min to name (safest). 'Separate Folder' keeps them organized. 'Overwrite' replaces originals (Dangerous!).", comment: ""), onHover: updateHover) {
                                Menu {
                                    ForEach(SaveMode.allCases, id: \.self) { mode in
                                        Button(mode.rawValue.capitalized) { settingsStore.saveMode = mode }
                                    }
                                } label: {
                                    Text(settingsStore.saveMode.rawValue.capitalized)
                                }
                            }
                            
                            if settingsStore.saveMode == .overwrite {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 10))
                                        .offset(y: 1)
                                    Text(NSLocalizedString("Warning: Original files will be replaced and cannot be recovered.", comment: ""))
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
                .padding(10)
            }
            
            // Info Area / Status Bar
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                    .background(Color.proBorder)
                
                HStack(alignment: .top, spacing: 4) {
                    if !hoverInfo.isEmpty {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .offset(y: 1) // Align with text
                    }
                    Text(hoverInfo.isEmpty ? NSLocalizedString("Hover over settings for details.", comment: "") : NSLocalizedString(hoverInfo, comment: ""))
                        .font(.system(size: 10))
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color.proTextMuted)
                .frame(height: 75, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            .background(Color.proPanel)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color.proPanel)
        .border(width: 1, edges: [.trailing], color: Color.proBorder)
    }
    
    private func savePresetAndClose() {
        if !newPresetName.isEmpty {
            settingsStore.saveCurrentAsPreset(name: newPresetName)
            newPresetName = ""
            isShowingSavePresetAlert = false
        }
    }
    
    private func updateHover(text: String) {
        self.hoverInfo = text
    }
    
    private var currentPresetName: String {
        if settingsStore.preset == .custom {
            if let id = settingsStore.activeUserPresetId,
               let match = settingsStore.userPresets.first(where: { $0.id == id }) {
                return match.name
            }
            return "Custom"
        }
        return settingsStore.preset.rawValue.capitalized
    }

    private enum SvgLevel {
        case safe
        case balanced
        case max
    }

    private var svgLevel: SvgLevel {
        if settingsStore.svgPrecision <= 2 && settingsStore.svgMultipass {
            return .max
        }
        if settingsStore.svgPrecision >= 5 {
            return .safe
        }
        return .balanced
    }

    private var svgLevelLabel: String {
        switch svgLevel {
        case .safe: return NSLocalizedString("Safe", comment: "")
        case .balanced: return NSLocalizedString("Balanced", comment: "")
        case .max: return NSLocalizedString("Max", comment: "")
        }
    }

    private func setSvgLevel(_ level: SvgLevel) {
        switch level {
        case .safe:
            settingsStore.svgPrecision = 5
            settingsStore.svgMultipass = false
        case .balanced:
            settingsStore.svgPrecision = 3
            settingsStore.svgMultipass = false
        case .max:
            settingsStore.svgPrecision = 2
            settingsStore.svgMultipass = true
        }
    }

}

struct SidebarOptionRow<Content: View>: View {
    let title: String
    let hint: String
    let onHover: (String) -> Void
    let valueContent: Content
    
    init(title: String, hint: String, onHover: @escaping (String) -> Void, @ViewBuilder value: () -> Content) {
        self.title = title
        self.hint = hint
        self.onHover = onHover
        self.valueContent = value()
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color.proTextMain)
            Spacer()
            valueContent
                .font(.system(size: 12))
                .foregroundColor(Color.proTextMain)
                .menuStyle(.borderlessButton)
                .fixedSize()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                onHover(hint)
            } else {
                onHover("")
            }
        }
    }
}

struct SidebarGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.proTextMuted)
                .padding(.leading, 8)
                .padding(.bottom, 2)
            
            content
        }
    }
}
