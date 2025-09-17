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
            VStack(spacing: 20) {
                SettingsSection(
                    title: "Качество и скорость",
                    subtitle: "Выберите баланс между размером файлов и визуальным качеством",
                    icon: "slider.horizontal.3"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Preset", selection: $preset) {
                            Text("Качество").tag(CompressionPreset.quality)
                            Text("Сбалансированно").tag(CompressionPreset.balanced)
                            Text("Экономия").tag(CompressionPreset.saving)
                            Text("Автоматически").tag(CompressionPreset.auto)
                        }
                        .pickerStyle(.segmented)

                        SettingHint(text: "Умный режим автоматически подстраивает компрессию под содержимое изображений.")

                        Picker("Режим сохранения", selection: $saveMode) {
                            Label("Суффикс", systemImage: "rectangle.and.pencil.and.ellipsis").tag(SaveMode.suffix)
                            Label("Отдельная папка", systemImage: "folder.badge.plus").tag(SaveMode.separateFolder)
                            Label("Перезаписать", systemImage: "arrow.triangle.2.circlepath").tag(SaveMode.overwrite)
                        }
                        .pickerStyle(.segmented)

                        SettingHint(text: "Суффикс добавляет _compressed к имени файла, отдельная папка создаёт каталог compressed рядом с исходниками.")
                    }
                }

                SettingsSection(
                    title: "Дополнительные параметры",
                    subtitle: "Оптимизируйте обработку и цветовые профили",
                    icon: "wand.and.stars"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $preserveMetadata) {
                            SettingsToggleLabel(
                                title: "Сохранять метаданные",
                                caption: "EXIF, GPS и другая служебная информация останется в итоговом файле.",
                                systemImage: "doc.text.image"
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Toggle(isOn: $convertToSRGB) {
                            SettingsToggleLabel(
                                title: "Конвертировать в sRGB",
                                caption: "Гарантирует одинаковый цвет в браузерах и приложениях без поддержки широких профилей.",
                                systemImage: "paintpalette"
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Toggle(isOn: $enableGifsicle) {
                            SettingsToggleLabel(
                                title: "Включить GIF оптимизацию",
                                caption: "Использует gifsicle для более гладкой анимации и меньшего веса.",
                                systemImage: "sparkles"
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }

                SettingsSection(
                    title: "Интерфейс",
                    subtitle: "Настройте внешний вид и элементы управления",
                    icon: "paintbrush.pointed"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Режим темы", selection: $appearanceMode) {
                            Label("Авто", systemImage: "circle.lefthalf.filled").tag(AppearanceMode.auto)
                            Label("Светлая", systemImage: "sun.max.fill").tag(AppearanceMode.light)
                            Label("Тёмная", systemImage: "moon.fill").tag(AppearanceMode.dark)
                        }
                        .pickerStyle(.segmented)

                        SettingHint(text: "Нажмите ⌘⇧A, чтобы быстро переключать режимы темы во время работы.")

                        Toggle(isOn: $showDockIcon) {
                            SettingsToggleLabel(
                                title: "Иконка в Dock",
                                caption: "Полезно, если хотите держать приложение в фоне и возвращаться к нему позже.",
                                systemImage: "macwindow"
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                        Toggle(isOn: $showMenuBarIcon) {
                            SettingsToggleLabel(
                                title: "Иконка в строке меню",
                                caption: "Быстрый доступ к перетаскиванию и истории запусков.",
                                systemImage: "menubar.rectangle"
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                }

                SettingsSection(
                    title: "Движки сжатия",
                    subtitle: "Задействованные инструменты и ожидаемая экономия",
                    icon: "chart.bar.doc.horizontal"
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        CompressionEngineRow(format: "JPEG", engine: "MozJPEG", improvement: "+35-40%", color: .green)
                        CompressionEngineRow(format: "PNG", engine: "Oxipng", improvement: "+15-20%", color: .blue)
                        CompressionEngineRow(format: "GIF", engine: "Gifsicle", improvement: "+30-50%", color: .orange)
                        CompressionEngineRow(format: "AVIF", engine: "libavif", improvement: "+20-30%", color: .purple)
                        CompressionEngineRow(format: "WebP", engine: "ImageIO", improvement: "Системный", color: .gray)
                        CompressionEngineRow(format: "HEIC", engine: "ImageIO", improvement: "Системный", color: .gray)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: resetToDefaults) {
                        Label("Сбросить настройки", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    SettingHint(text: "Настройки сохраняются автоматически и синхронизируются с выбранным режимом.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .frame(width: 440)
    }

    private func resetToDefaults() {
        preset = .balanced
        saveMode = .suffix
        preserveMetadata = true
        convertToSRGB = false
        enableGifsicle = true
        appearanceMode = .auto
        showDockIcon = true
        showMenuBarIcon = true

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

struct CompressionEngineRow: View {
    let format: String
    let engine: String
    let improvement: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(format)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(engine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(improvement)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color == .gray ? .secondary : color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, subtitle: String? = nil, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } icon: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                }
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05))
        )
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.secondary.opacity(0.08)
    }
}

private struct SettingsToggleLabel: View {
    let title: String
    let caption: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingHint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
