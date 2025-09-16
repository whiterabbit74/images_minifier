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
            VStack(alignment: .leading, spacing: 20) {
                Text("Настройки сжатия")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Качество сжатия:")
                        .fontWeight(.medium)

                    Picker("Preset", selection: $preset) {
                        Text("Качество").tag(CompressionPreset.quality)
                        Text("Сбалансированно").tag(CompressionPreset.balanced)
                        Text("Экономия").tag(CompressionPreset.saving)
                        Text("Автоматически").tag(CompressionPreset.auto)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Режим сохранения:")
                        .fontWeight(.medium)

                    Picker("Save Mode", selection: $saveMode) {
                        Text("С суффиксом").tag(SaveMode.suffix)
                        Text("В папку").tag(SaveMode.separateFolder)
                        Text("Перезаписать").tag(SaveMode.overwrite)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Сохранять метаданные", isOn: $preserveMetadata)
                    Toggle("Конвертировать в sRGB", isOn: $convertToSRGB)
                    Toggle("Включить GIF оптимизацию", isOn: $enableGifsicle)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Движки сжатия:")
                        .fontWeight(.medium)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 6) {
                        CompressionEngineRow(format: "JPEG", engine: "MozJPEG", improvement: "+35-40%", color: .green)
                        CompressionEngineRow(format: "PNG", engine: "Oxipng", improvement: "+15-20%", color: .blue)
                        CompressionEngineRow(format: "GIF", engine: "Gifsicle", improvement: "+30-50%", color: .orange)
                        CompressionEngineRow(format: "AVIF", engine: "libavif", improvement: "+20-30% vs WebP", color: .purple)
                        CompressionEngineRow(format: "WebP", engine: "ImageIO", improvement: "Системный", color: .gray)
                        CompressionEngineRow(format: "HEIC", engine: "ImageIO", improvement: "Системный", color: .gray)
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Интерфейс:")
                        .fontWeight(.medium)

                    Picker("Тема", selection: $appearanceMode) {
                        Text("Светлая").tag(AppearanceMode.light)
                        Text("Темная").tag(AppearanceMode.dark)
                        Text("Системная").tag(AppearanceMode.auto)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Toggle("Показывать в Dock", isOn: $showDockIcon)
                    Toggle("Показывать в строке меню", isOn: $showMenuBarIcon)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 420)
        .frame(maxHeight: 600)
    }
}

struct CompressionEngineRow: View {
    let format: String
    let engine: String
    let improvement: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Format badge
            Text(format)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
                .frame(minWidth: 45)

            // Engine name
            Text(engine)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(minWidth: 70, alignment: .leading)

            Spacer()

            // Improvement indicator
            Text(improvement)
                .font(.caption2)
                .foregroundColor(color == .gray ? .secondary : color)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}
