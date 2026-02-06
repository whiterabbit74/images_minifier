import SwiftUI
import PicsMinifierCore

struct StatisticsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore
    
    var body: some View {
        Group {
            if settingsStore.disableStatistics {
                emptyState
            } else {
                statisticsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.proBg)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(Color.proTextMuted)
            
            Text(NSLocalizedString("Statistics Disabled", comment: ""))
                .font(.headline)
                .foregroundColor(Color.proTextMain)
            
            Text(NSLocalizedString("Enable statistics in settings to track your savings.", comment: ""))
                .font(.subheadline)
                .foregroundColor(Color.proTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var statisticsContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 4) {
                    Text(NSLocalizedString("Statistics", comment: ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.proTextMain)
                    Text(NSLocalizedString("Session and lifetime performance metrics", comment: ""))
                        .font(.system(size: 13))
                        .foregroundColor(Color.proTextMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // MAIN GRID
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // Total Saved
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("TOTAL SPACE SAVED", comment: ""))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.proTextMuted)
                        
                        Text(ByteCountFormatter.string(fromByteCount: Int64(settingsStore.lifetimeSavedBytes), countStyle: .file))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        if sessionStore.sessionSavedBytes > 0 {
                            Text("+\(ByteCountFormatter.string(fromByteCount: Int64(sessionStore.sessionSavedBytes), countStyle: .file)) \(NSLocalizedString("in last session", comment: ""))")
                                .font(.system(size: 11))
                                .foregroundColor(.proGreen)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.proPanel)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.proBorder, lineWidth: 1))
                    
                    // Average Reduction
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("AVERAGE REDUCTION", comment: ""))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.proTextMuted)
                        
                        let reduction = calculateReduction()
                        Text(String(format: "%.1f%%", reduction * 100))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.proBorder)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.proGreen)
                                    .frame(width: geo.size.width * CGFloat(reduction))
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.proPanel)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.proBorder, lineWidth: 1))
                }

                // CHARTS SECTION
                HStack(alignment: .top, spacing: 20) {
                    // Files Processed
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(format: NSLocalizedString("TOTAL FILES PROCESSED: %d", comment: ""), settingsStore.lifetimeCompressedCount))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.proTextMuted)
                        
                        if sessionStore.sessionCompressedCount > 0 {
                            Text("+\(sessionStore.sessionCompressedCount) \(NSLocalizedString("in last session", comment: ""))")
                                .font(.system(size: 11))
                                .foregroundColor(.proGreen)
                                .padding(.top, -8)
                        }
                        
                        // Fake Activity Chart (Bars)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<7) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.proAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: CGFloat.random(in: 10...80))
                            }
                        }
                        .frame(height: 100)
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.proPanel)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.proBorder, lineWidth: 1))
                    
                    // Format Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("SAVINGS BY FORMAT", comment: ""))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.proTextMuted)
                        
                        VStack(spacing: 8) {
                            let formatStats = getFormatStats()
                            ForEach(formatStats, id: \.name) { stat in
                                HStack {
                                    Circle()
                                        .fill(stat.color)
                                        .frame(width: 8, height: 8)
                                    Text(stat.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.proTextMain)
                                    Spacer()
                                    Text(String(format: "%.0f%%", stat.percentage * 100))
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.proTextMuted)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.proPanel)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.proBorder, lineWidth: 1))
                }

                // LIBRARIES
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("LIBRARIES", comment: ""))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.proTextMuted)

                    LazyVGrid(columns: libraryColumns, spacing: 12) {
                        ForEach(libraryItems, id: \.format) { item in
                            LibraryChip(item: item)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func calculateReduction() -> Double {
        guard settingsStore.lifetimeOriginalBytes > 0 else { return 0 }
        return Double(settingsStore.lifetimeSavedBytes) / Double(settingsStore.lifetimeOriginalBytes)
    }
    
    struct FormatStat {
        let name: String
        let percentage: Double
        let color: Color
    }
    
    private func getFormatStats() -> [FormatStat] {
        let savings = settingsStore.formatSavings
        let total = Double(savings.values.reduce(0, +))
        guard total > 0 else { return [] }
        
        let sortedFormats = savings.keys.sorted { (savings[$0] ?? 0) > (savings[$1] ?? 0) }
        let topFormats = Array(sortedFormats.prefix(3))
        
        var results: [FormatStat] = []
        let colors: [Color] = [.proAccent, .proGreen, .proOrange, .proPurple]
        
        for (index, format) in topFormats.enumerated() {
            let value = Double(savings[format] ?? 0)
            results.append(FormatStat(name: format.uppercased(), percentage: value / total, color: colors[index % colors.count]))
        }
        
        if sortedFormats.count > 3 {
            let otherValue = Double(sortedFormats.suffix(from: 3).reduce(0) { $0 + (savings[$1] ?? 0) })
            results.append(FormatStat(name: NSLocalizedString("OTHER", comment: ""), percentage: otherValue / total, color: colors.last!))
        }
        
        return results
    }

    private var libraryColumns: [GridItem] {
        return [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    private var libraryItems: [LibraryItem] {
        let availability = ConfigurationManager.shared.checkToolAvailability()
        let webp = WebPEncoder().availability()

        let jpegAvailable = availability.cjpeg || availability.cjpegli
        let pngAvailable = availability.oxipng
        let gifAvailable = availability.gifsicle
        let avifAvailable = availability.avifenc
        let svgAvailable = availability.svgcleaner

        let webpAvailable = availability.cwebp || webp != .unavailable

        let webpName: String
        if availability.cwebp {
            webpName = "cwebp (libwebp)"
        } else {
            switch webp {
            case .embedded: webpName = "libwebp (embedded)"
            case .systemCodec: webpName = "ImageIO"
            case .unavailable: webpName = "None"
            }
        }

        return [
            LibraryItem(format: "JPEG", library: jpegAvailable ? "MozJPEG" : "ImageIO", available: jpegAvailable),
            LibraryItem(format: "PNG", library: pngAvailable ? "Oxipng" : "ImageIO", available: pngAvailable),
            LibraryItem(format: "GIF", library: gifAvailable ? "Gifsicle" : "ImageIO", available: gifAvailable),
            LibraryItem(format: "WebP", library: webpName, available: webpAvailable),
            LibraryItem(format: "AVIF", library: avifAvailable ? "avifenc" : "ImageIO", available: avifAvailable),
            LibraryItem(format: "SVG", library: svgAvailable ? "svgcleaner" : "None", available: svgAvailable)
        ]
    }
}

private struct LibraryItem {
    let format: String
    let library: String
    let available: Bool
}

private struct LibraryChip: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(item.available ? .proGreen : .proTextMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.format)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.proTextMain)
                Text(item.library)
                    .font(.system(size: 10))
                    .foregroundColor(.proTextMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.proPanel)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.proBorder, lineWidth: 1)
        )
    }
}
