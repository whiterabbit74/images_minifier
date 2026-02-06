import SwiftUI
import PicsMinifierCore

struct SidebarView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.colorScheme) var colorScheme
    @State private var hoverInfo: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // PRESETS
                    SidebarGroup(title: "PRESETS") {
                        VStack(spacing: 0) {
                            // Main Preset
                            SidebarOptionRow(title: "Base Preset", hint: "Start here to set a baseline. 'Balanced' (recommended) is the best mix of size and quality. 'Quality' prioritizes details. 'Saving' aggressively reduces size.", onHover: updateHover) {
                                Menu {
                                    ForEach(CompressionPreset.allCases, id: \.self) { preset in
                                        Button(preset.rawValue.capitalized) { settingsStore.preset = preset }
                                    }
                                } label: {
                                    Text(settingsStore.preset.rawValue.capitalized)
                                }
                            }

                            // JPEG Quality
                            SidebarOptionRow(title: "JPEG Quality", hint: "Controls clarity. 80-85% is the 'sweet spot'—visually identical to original but much smaller. Go lower (60-70%) only if file size is critical.", onHover: updateHover) {
                                Menu {
                                    Text("Quality: \(Int(settingsStore.customJpegQuality * 100))%")
                                    Button("60%") { settingsStore.customJpegQuality = 0.6 }
                                    Button("70%") { settingsStore.customJpegQuality = 0.7 }
                                    Button("80%") { settingsStore.customJpegQuality = 0.8 }
                                    Button("85%") { settingsStore.customJpegQuality = 0.85 }
                                    Button("90%") { settingsStore.customJpegQuality = 0.9 }
                                    Button("95%") { settingsStore.customJpegQuality = 0.95 }
                                    Divider()
                                    Button("Steps") { }
                                        .disabled(true)
                                } label: {
                                    Text("\(Int(settingsStore.customJpegQuality * 100))%")
                                }
                            }
                            
                            // PNG Level
                            SidebarOptionRow(title: "PNG Safe", hint: "How hard the CPU works to find patterns. Level 3 is fast. Level 9 tries everything to squeeze out bytes (can be very slow). No quality is lost.", onHover: updateHover) {
                                Menu {
                                    ForEach(0...9, id: \.self) { level in
                                        Button("Level \(level)") { settingsStore.customPngLevel = level }
                                    }
                                } label: {
                                    Text("L\(settingsStore.customPngLevel)")
                                }
                            }
                            
                            // AVIF Quality
                            SidebarOptionRow(title: "AVIF Quality", hint: "Modern format quality. Lower numbers (20-30) are excellent. Higher (50+) keep more noise/grain but produce larger files.", onHover: updateHover) {
                                Menu {
                                    ForEach([20, 28, 35, 45, 55, 63], id: \.self) { q in
                                        Button("\(q)") { settingsStore.customAvifQuality = q }
                                    }
                                } label: {
                                    Text("\(settingsStore.customAvifQuality)")
                                }
                            }
                            
                            // AVIF Speed
                            SidebarOptionRow(title: "AVIF Speed", hint: "Encoding effort (0-10). Speed 0 is painfully slow but creates the smallest files. Speed 6+ is instant. Speed 4 is a good balance.", onHover: updateHover) {
                                Menu {
                                    ForEach(0...10, id: \.self) { s in
                                        Button("Speed \(s)") { settingsStore.customAvifSpeed = s }
                                    }
                                } label: {
                                    Text("\(settingsStore.customAvifSpeed)")
                                }
                            }
                            
                            // GIF Lossy
                            SidebarOptionRow(title: "GIF Mode", hint: "Lossy (Gifsicle) is magic for GIFs—it can reduce size by 70% by slightly simplifying colors. Lossless keeps every pixel but stays huge.", onHover: updateHover) {
                                Menu {
                                    Button("Lossy (Gifsicle)") { settingsStore.enableGifsicle = true }
                                    Button("Lossless") { settingsStore.enableGifsicle = false }
                                } label: {
                                    Text(settingsStore.enableGifsicle ? "Lossy" : "Lossless")
                                }
                            }
                        }
                    }

                    // OUTPUT
                    SidebarGroup(title: "OUTPUT") {
                        VStack(spacing: 0) {
                            SidebarOptionRow(title: "Mode", hint: "Where files go: 'Suffix' adds _min to name (safest). 'Separate Folder' keeps them organized. 'Overwrite' replaces originals (Dangerous!).", onHover: updateHover) {
                                Menu {
                                    ForEach(SaveMode.allCases, id: \.self) { mode in
                                        Button(mode.rawValue.capitalized) { settingsStore.saveMode = mode }
                                    }
                                } label: {
                                    Text(settingsStore.saveMode.rawValue.capitalized)
                                }
                            }
                            
                            SidebarOptionRow(title: "Metadata", hint: "Data like GPS, Camera Model, DateTime. Keeping it maintains history. Stripping it protects privacy and saves a few KB.", onHover: updateHover) {
                                Menu {
                                    Button("Keep") { settingsStore.preserveMetadata = true }
                                    Button("Strip") { settingsStore.preserveMetadata = false }
                                } label: {
                                    Text(settingsStore.preserveMetadata ? "Keep" : "Strip")
                                }
                            }
                            
                            SidebarOptionRow(title: "Color", hint: "Most web images should be sRGB. Converting fixes washed-out colors on some displays. 'Original' keeps wide-gamut data.", onHover: updateHover) {
                                Menu {
                                    Button("sRGB") { settingsStore.convertToSRGB = true }
                                    Button("Original") { settingsStore.convertToSRGB = false }
                                } label: {
                                    Text(settingsStore.convertToSRGB ? "sRGB" : "Orig")
                                }
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
                    Text(hoverInfo.isEmpty ? "Hover over settings for details.\nWe'll explain what they do right here." : hoverInfo)
                        .font(.system(size: 10))
                        .lineLimit(6) // Increased to 6
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Color.proTextMuted)
                .frame(height: 75, alignment: .topLeading) // Increased to 75
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            .background(Color.proPanel)
            .padding(.bottom, 8)

            // Theme (Moved to bottom of VStack if desired, or kept inside scroll view if needed. 
            // Design requires fixed sidebar elements at bottom often. Let's keep Theme below Info)
            
            HStack {
                Text("Theme")
                    .font(.system(size: 11))
                    .foregroundColor(Color.proTextMuted)
                Spacer()
                Menu {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue.capitalized) { settingsStore.appearanceMode = mode }
                    }
                } label: {
                    Text(settingsStore.appearanceMode.rawValue.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(Color.proTextMain)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(12)
            .background(Color.proBorder.opacity(0.3))
        }
        .frame(width: 200)
        .background(Color.proPanel)
        .border(width: 1, edges: [.trailing], color: Color.proBorder)
    }
    
    private func updateHover(text: String) {
        self.hoverInfo = text
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
                // We only clear if the parent thinks WE are the one showing.
                // But simplified: parent might get a clear from us.
                // Better UX: only clear if *we* were the one setting it? 
                // But Sidebar is simple enough: we just clear it.
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
