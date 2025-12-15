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
                        }
                        .pickerStyle(.segmented)

                        SettingHint(text: "Умный режим подстраивает уровень сжатия под каждое изображение.")
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
