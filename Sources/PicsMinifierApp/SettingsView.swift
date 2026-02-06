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
                // Заголовок
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(NSLocalizedString("Настройки", comment: ""))
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.top, 8)

                // 🎨 ВНЕШНИЙ ВИД
                GroupBox(label: Label("Внешний вид", systemImage: "eye.fill")
                    .foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Режим оформления
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Режим оформления")
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
                                    Text(NSLocalizedString("Светлая", comment: ""))
                                }.tag(AppearanceMode.light)

                                HStack {
                                    Image(systemName: "moon.fill")
                                    Text(NSLocalizedString("Тёмная", comment: ""))
                                }.tag(AppearanceMode.dark)

                                HStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                    Text(NSLocalizedString("Как в системе", comment: ""))
                                }.tag(AppearanceMode.auto)
                            }
                            .pickerStyle(.radioGroup)
                        }

                        Divider()

                        // Режим отображения (Interface Mode)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Режим интерфейса")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 0) {
                                // Dock Only
                                InterfaceModeButton(
                                    mode: .dock,
                                    current: interfaceMode,
                                    icon: "dock.rectangle",
                                    title: "Dock"
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
                                    title: "Везде"
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
                                    title: "Menu Bar"
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

                        // Показывать только с экономией
                        HStack {
                            Toggle(NSLocalizedString("Показывать только с экономией", comment: ""), isOn: $showOnlyWithGain)
                                .onChange(of: showOnlyWithGain) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }
                    }
                    .padding(12)
                }

                // 🔧 КАЧЕСТВО СЖАТИЯ
                GroupBox(label: Label("Качество сжатия", systemImage: "wand.and.stars")
                    .foregroundColor(.green)) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Пресет сжатия")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: Binding(
                                get: { CompressionPreset(rawValue: presetRaw) ?? .balanced },
                                set: { presetRaw = $0.rawValue; notify() }
                            )) {
                                HStack {
                                    Image(systemName: "star.fill")
                                    Text(NSLocalizedString("Максимальное качество", comment: ""))
                                }.tag(CompressionPreset.quality)

                                HStack {
                                    Image(systemName: "circle.fill")
                                    Text(NSLocalizedString("Оптимальный баланс", comment: ""))
                                }.tag(CompressionPreset.balanced)

                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text(NSLocalizedString("Максимальная экономия", comment: ""))
                                }.tag(CompressionPreset.saving)

                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text(NSLocalizedString("Автоматически", comment: ""))
                                }.tag(CompressionPreset.auto)
                            }
                            .pickerStyle(.radioGroup)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Способ сохранения файлов")
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
                                    Text(NSLocalizedString("Добавить суффикс '_compressed'", comment: ""))
                                }.tag(SaveMode.suffix)

                                HStack {
                                    Image(systemName: "folder.fill")
                                    Text(NSLocalizedString("Создать папку 'Compressor'", comment: ""))
                                }.tag(SaveMode.separateFolder)

                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(NSLocalizedString("Перезаписать оригиналы", comment: ""))
                                }.tag(SaveMode.overwrite)
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                    .padding(12)
                }

                // 📏 РАЗМЕРЫ ИЗОБРАЖЕНИЙ
                GroupBox(label: Label("Размеры изображений", systemImage: "rectangle.resize")
                    .foregroundColor(.purple)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Максимальный размер
                        HStack {
                            Text("Максимальный размер стороны")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }

                        HStack(spacing: 12) {
                            TextField("", text: $maxDimText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                                .onChange(of: maxDimText) { _ in applyMaxDimText() }

                            Text("пикселей")
                                .foregroundColor(.secondary)

                            Spacer()

                            if maxDimension == 0 {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Без ограничений")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "arrow.down.right.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Размер ограничен")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        Text("0 — без ограничения размера")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()

                        Divider()

                        // Метаданные
                        HStack {
                            Toggle(NSLocalizedString("Сохранять метаданные", comment: ""), isOn: $preserveMetadata)
                                .onChange(of: preserveMetadata) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }

                        HStack {
                            Toggle(NSLocalizedString("Конвертировать в sRGB", comment: ""), isOn: $convertToSRGB)
                                .onChange(of: convertToSRGB) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }

                        HStack {
                            Toggle(NSLocalizedString("Оптимизировать GIF", comment: ""), isOn: $enableGifsicle)
                                .onChange(of: enableGifsicle) { _ in notify() }
                                .toggleStyle(.switch)
                            Spacer()
                        }
                    }
                    .padding(12)
                }

                // 📊 СТАТИСТИКА
                GroupBox(label: Label("Статистика", systemImage: "chart.bar.fill")
                    .foregroundColor(.orange)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(format: NSLocalizedString("Обработано файлов: %lld", comment: ""), StatsStore.shared.allTimeProcessedCount))
                                    .font(.headline)
                                Text(String(format: NSLocalizedString("Общая экономия: %@", comment: ""), ByteCountFormatter.string(fromByteCount: StatsStore.shared.allTimeSavedBytes, countStyle: .file)))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }

                        Divider()

                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                resetStatsAndLogs()
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text(NSLocalizedString("Сбросить статистику", comment: ""))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                }

                // 📁 ПОДДЕРЖИВАЕМЫЕ ФОРМАТЫ
                GroupBox(label: Label("Поддерживаемые форматы", systemImage: "doc.badge.gearshape.fill")
                    .foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Какие библиотеки используются для обработки файлов")
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
                                description: "Системный HEIF кодек",
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
                                description: "Системный TIFF кодек с LZW",
                                hasOptions: false
                            )
                        }

                        // Информация об улучшениях
                        if needsModernTools() {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Улучшите сжатие!")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    if !jpegHasOptions() {
                                        Text("• JPEG: установите MozJPEG для +35% лучшего сжатия")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !pngHasOptions() {
                                        Text("• PNG: установите Oxipng для +20% лучшего сжатия")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !gifHasOptions() {
                                        Text("• GIF: установите Giflossy для +30% лучшего сжатия")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack {
                                    Text("Команда: brew install mozjpeg oxipng giflossy")
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

                // 🔍 ДИАГНОСТИКА И ИНСТРУМЕНТЫ
                GroupBox(label: Label("Инструменты", systemImage: "wrench.and.screwdriver.fill")
                    .foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Проверка доступности инструментов")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            Button {
                                let availability = WebPEncoder().availability()
                                var msg = ""
                                switch availability {
                                case .systemCodec: msg = NSLocalizedString("✅ Системный кодек WebP доступен", comment: "")
                                case .embedded: msg = NSLocalizedString("✅ Встроенный WebP доступен", comment: "")
                                case .unavailable: msg = NSLocalizedString("❌ WebP не доступен", comment: "")
                                }
                                showInfoAlert(title: "WebP", message: msg)
                            } label: {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("WebP")
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
                                let msg = found.isEmpty ? NSLocalizedString("❌ gifsicle не найден", comment: "") : String(format: NSLocalizedString("✅ gifsicle: %@", comment: ""), found)
                                showInfoAlert(title: "gifsicle", message: msg)
                            } label: {
                                HStack {
                                    Image(systemName: "film.fill")
                                    Text("GIF")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }

                        Divider()

                        DisclosureGroup("Дополнительно") {
                            HStack(spacing: 12) {
                                Button {
                                    NSWorkspace.shared.open(AppPaths.logCSVURL())
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("CSV лог")
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
                                        Text("Папка логов")
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
        .alert(NSLocalizedString("Перезапись оригиналов", comment: ""), isPresented: $confirmOverwrite) {
            Button(NSLocalizedString("Отмена", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("Продолжить", comment: ""), role: .destructive) {
                saveModeRaw = SaveMode.overwrite.rawValue
                notify()
            }
        } message: {
            Text(NSLocalizedString("Файлы будут перезаписаны без возможности восстановления. Вы уверены?", comment: ""))
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
        alert.messageText = NSLocalizedString("Сбросить статистику?", comment: "")
        alert.informativeText = NSLocalizedString("Будут обнулены счётчики и удалён CSV лог. Действие необратимо.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Сбросить", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Отмена", comment: ""))
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            StatsStore.shared.resetAll()
            let url = AppPaths.logCSVURL()
            try? FileManager.default.removeItem(at: url)
            _ = CSVLogger(logURL: url) // пересоздаём с заголовком
            notify()
        }
    }

    private func webpProcessorName() -> String {
        let encoder = WebPEncoder()
        switch encoder.availability() {
        case .systemCodec: return "ImageIO (macOS)"
        case .embedded: return "libwebp (встроенная)"
        case .unavailable: return "Недоступно"
        }
    }

    private func webpProcessorDescription() -> String {
        let encoder = WebPEncoder()
        switch encoder.availability() {
        case .systemCodec: return "Системный WebP кодек"
        case .embedded: return "Встроенная библиотека libwebp"
        case .unavailable: return "WebP кодек не найден"
        }
    }

    private func webpHasOptions() -> Bool {
        let encoder = WebPEncoder()
        return encoder.availability() != .unavailable
    }

    private func gifsicleStatus() -> String {
        let modernGif = ModernGifOptimizer()
        let tools = modernGif.getAvailableTools()
        return tools.isEmpty ? "Не найден" : tools.first ?? "Не найден"
    }

    // Новые методы для современных компрессоров
    private func jpegProcessorName() -> String {
        let mozjpeg = MozJPEGCompressor()
        return mozjpeg.isAvailable() ? "MozJPEG" : "ImageIO (macOS)"
    }

    private func jpegProcessorDescription() -> String {
        let mozjpeg = MozJPEGCompressor()
        return mozjpeg.isAvailable() ? "Современный JPEG оптимизатор (+35% сжатие)" : "Системный JPEG кодек"
    }

    private func pngProcessorName() -> String {
        let oxipng = OxipngCompressor()
        return oxipng.isAvailable() ? "Oxipng" : "ImageIO (macOS)"
    }

    private func pngProcessorDescription() -> String {
        let oxipng = OxipngCompressor()
        return oxipng.isAvailable() ? "Быстрый PNG оптимизатор (+20% сжатие)" : "Системный PNG кодек"
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
            return "Не найден"
        }
    }

    private func gifProcessorDescription() -> String {
        let modernGif = ModernGifOptimizer()
        let tools = modernGif.getAvailableTools()
        if tools.contains(where: { $0.contains("Giflossy") }) {
            return "Продвинутый GIF оптимизатор (+30% сжатие)"
        } else if tools.contains(where: { $0.contains("Gifsicle") }) {
            return "Базовый GIF оптимизатор"
        } else {
            return "Оптимизатор не найден"
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
            // Иконка формата
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            // Расширения
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

            // Разделитель
            Text("→")
                .foregroundColor(.secondary)

            // Информация о процессоре
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


