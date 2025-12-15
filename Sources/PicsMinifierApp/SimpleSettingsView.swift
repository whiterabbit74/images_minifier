import SwiftUI
import PicsMinifierCore

struct SimpleSettingsView: View {
    @Binding var preset: CompressionPreset
    @Binding var saveMode: SaveMode
    @Binding var preserveMetadata: Bool
    @Binding var convertToSRGB: Bool
    @Binding var enableGifsicle: Bool
    @Binding var appearanceMode: AppearanceMode
    @Binding var showDockIcon: Bool
    @Binding var showMenuBarIcon: Bool
    
    // Custom Settings
    @Binding var customJpegQuality: Double
    @Binding var customPngLevel: Int
    @Binding var customAvifQuality: Int
    @Binding var customAvifSpeed: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Настройки")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 4)

                SettingsSection(
                    title: "Качество",
                    icon: "slider.horizontal.3"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Preset", selection: $preset) {
                            Text("Качество").tag(CompressionPreset.quality)
                            Text("Баланс").tag(CompressionPreset.balanced)
                            Text("Сжатие").tag(CompressionPreset.saving)
                            Text("Авто").tag(CompressionPreset.auto)
                            Text("Ручной").tag(CompressionPreset.custom)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: preset) { _ in saveSettings() }

                        if preset == .custom {
                            CustomSettingsPanel(
                                jpegQuality: $customJpegQuality,
                                pngLevel: $customPngLevel,
                                avifQuality: $customAvifQuality,
                                avifSpeed: $customAvifSpeed
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            SettingHint(text: "Умный режим подстраивает уровень сжатия под каждое изображение.")
                        }
                    }
                }

                SettingsSection(
                    title: "Сохранение",
                    icon: "folder"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Режим", selection: $saveMode) {
                            Text("Суффикс").tag(SaveMode.suffix)
                            Text("Папка").tag(SaveMode.separateFolder)
                            Text("Замена").tag(SaveMode.overwrite)
                        }
                        .pickerStyle(.segmented)
                        
                        SettingHint(text: saveModeDescription)
                    }
                }

                SettingsSection(
                    title: "Опции",
                    icon: "gearshape.2"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        GlassToggle(isOn: $preserveMetadata, title: "Сохранять метаданные", subtitle: "EXIF, GPS, Copyright", icon: "doc.text")
                        GlassToggle(isOn: $convertToSRGB, title: "sRGB Конвертация", subtitle: "Для веб-совместимости", icon: "paintpalette")
                        GlassToggle(isOn: $enableGifsicle, title: "GIF Оптимизация", subtitle: "Использовать Gifsicle", icon: "film")
                    }
                }

                SettingsSection(
                    title: "Интерфейс",
                    icon: "macwindow"
                ) {
                     VStack(alignment: .leading, spacing: 12) {
                        GlassToggle(isOn: $showDockIcon, title: "Иконка в Dock", subtitle: nil, icon: "dock.rectangle")
                        GlassToggle(isOn: $showMenuBarIcon, title: "Иконка в меню", subtitle: nil, icon: "menubar.rectangle")
                        
                        Divider().padding(.vertical, 4)
                        
                        Button(action: resetToDefaults) {
                            HStack {
                                Spacer()
                                Text("Сбросить настройки")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                     }
                }
                
                // Info Section
                VStack(spacing: 8) {
                    Text("PicsMinifier 2025")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .frame(width: 400)
    }

    private var saveModeDescription: String {
        switch saveMode {
        case .suffix: return "Добавляет _compressed к имени файла."
        case .separateFolder: return "Создает папку 'compressed' рядом с файлом."
        case .overwrite: return "Внимание: Исходные файлы будут заменены."
        }
    }

    private func resetToDefaults() {
        withAnimation {
            preset = .balanced
            saveMode = .suffix
            preserveMetadata = true
            convertToSRGB = false
            enableGifsicle = true
            appearanceMode = .auto
            showDockIcon = true
            showMenuBarIcon = true
            
            customJpegQuality = 0.82
            customPngLevel = 3
            customAvifQuality = 28
            customAvifSpeed = 4
        }
        saveSettings()
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(preset.rawValue, forKey: "settings.preset")
        defaults.set(saveMode.rawValue, forKey: "settings.saveMode")
        defaults.set(preserveMetadata, forKey: "settings.preserveMetadata")
        defaults.set(convertToSRGB, forKey: "settings.convertToSRGB")
        defaults.set(enableGifsicle, forKey: "settings.enableGifsicle")
        defaults.set(appearanceMode.rawValue, forKey: "ui.appearanceMode")
        defaults.set(showDockIcon, forKey: "ui.showDockIcon")
        defaults.set(showMenuBarIcon, forKey: "ui.showMenuBarIcon")
        
        defaults.set(customJpegQuality, forKey: "settings.customJpegQuality")
        defaults.set(customPngLevel, forKey: "settings.customPngLevel")
        defaults.set(customAvifQuality, forKey: "settings.customAvifQuality")
        defaults.set(customAvifSpeed, forKey: "settings.customAvifSpeed")
    }
}

// MARK: - Components

struct GlassToggle: View {
    @Binding var isOn: Bool
    let title: String
    let subtitle: String?
    let icon: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct SettingHint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

struct CustomSettingsPanel: View {
    @Binding var jpegQuality: Double
    @Binding var pngLevel: Int
    @Binding var avifQuality: Int
    @Binding var avifSpeed: Int

    var body: some View {
        VStack(spacing: 16) {
            Divider()
            
            // JPEG
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("JPEG Качество")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(jpegQuality * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $jpegQuality, in: 0.1...1.0)
            }
            
            // PNG
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("PNG Оптимизация")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Level \(pngLevel)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Picker("", selection: $pngLevel) {
                    ForEach(0...6, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // AVIF Quality
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AVIF Качество (CQ)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(avifQuality)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { Double(avifQuality) }, set: { avifQuality = Int($0) }), in: 0...63, step: 1)
                Text("Меньше = Лучше качество")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // AVIF Speed
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AVIF Скорость")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(avifSpeed)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                 Slider(value: Binding(get: { Double(avifSpeed) }, set: { avifSpeed = Int($0) }), in: 0...10, step: 1)
                 Text("Больше = Быстрей (хуже сжатие)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}
