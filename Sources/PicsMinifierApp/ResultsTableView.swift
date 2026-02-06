
import SwiftUI

struct ProcessedFile: Identifiable {
    let id = UUID()
    let url: URL
    var originalSize: Int64
    var optimizedSize: Int64
    var status: ProcessingStatus
    
    enum ProcessingStatus {
        case pending
        case processing
        case done
        case error
        case skipped
    }
    
    var name: String { url.lastPathComponent }
    
    var savingsPercent: Double {
        guard originalSize > 0 else { return 0 }
        return Double(originalSize - optimizedSize) / Double(originalSize)
    }
}

struct ResultsTableView: View {
    let files: [ProcessedFile]
    var onClear: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text(NSLocalizedString("File", comment: ""))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                
                Text(NSLocalizedString("Original", comment: ""))
                    .frame(width: 100, alignment: .trailing)
                
                Text(NSLocalizedString("Optimized", comment: ""))
                    .frame(width: 100, alignment: .trailing)
                
                Text(NSLocalizedString("Savings", comment: ""))
                    .frame(width: 100, alignment: .trailing)
                    .foregroundColor(Color.proGreen)
                    .padding(.trailing, 20)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.proTextMuted)
            .frame(height: 35)
            .background(Color.proPanel)
            .border(width: 1, edges: [.bottom], color: Color.proBorder)
            
            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        ResultsRow(file: file)
                    }
                }
            }
            .background(Color.proBg)
            
            // Summary Bar (Blue)
            if !files.isEmpty {
                let successful = files.filter { $0.status == .done }
                let totalOriginal = successful.reduce(0) { $0 + $1.originalSize }
                let totalOptimized = successful.reduce(0) { $0 + $1.optimizedSize }
                let totalSaved = max(0, totalOriginal - totalOptimized)
                let percent = totalOriginal > 0 ? Double(totalSaved) / Double(totalOriginal) * 100 : 0
                
                HStack {
                    Button(action: onClear) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text(NSLocalizedString("Clear List", comment: ""))
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(String.localizedStringWithFormat(NSLocalizedString("%d Files processed successfully", comment: ""), successful.count))
                        .opacity(0.8)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("Saved", comment: ""))
                        Text("\(ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file)) (\(Int(percent))%)")
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(Color.proAccent)
            }
        }
    }
}

struct ResultsRow: View {
    let file: ProcessedFile
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // File Name with Icon
            HStack(spacing: 12) {
                Image(systemName: iconFor(file))
                    .foregroundColor(Color.proTextMuted)
                    .frame(width: 20)
                
                Text(file.name)
                    .truncationMode(.middle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.proTextMain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            
            // Original
            Text(ByteCountFormatter.string(fromByteCount: file.originalSize, countStyle: .file))
                .monospacedDigit()
                .font(.system(size: 13))
                .foregroundColor(Color.proTextMuted)
                .frame(width: 100, alignment: .trailing)
            
            // Optimized
            Text(file.optimizedSize > 0 ? ByteCountFormatter.string(fromByteCount: file.optimizedSize, countStyle: .file) : "—")
                .monospacedDigit()
                .font(.system(size: 13))
                .foregroundColor(Color.proTextMuted)
                .frame(width: 100, alignment: .trailing)
            
            // Savings
            Text(savingsText)
                .monospacedDigit()
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(file.status == .done ? Color.proGreen : Color.proTextMuted)
                .frame(width: 100, alignment: .trailing)
                .padding(.trailing, 20)
        }
        .frame(height: 44)
        .background(isHovered ? Color(white: 0.17) : Color.clear)
        .onHover { hovering in isHovered = hovering }
        .border(width: 1, edges: [.bottom], color: Color.proBorder)
    }
    
    private func iconFor(_ file: ProcessedFile) -> String {
        let ext = file.url.pathExtension.lowercased()
        switch ext {
        case "png": return "photo"
        case "jpg", "jpeg": return "camera.fill"
        case "svg": return "square.on.circle"
        case "gif": return "film"
        case "webp": return "photo.stack"
        case "avif": return "photo.circle"
        case "heic": return "photo.on.rectangle"
        case "tiff", "tif": return "scroll"
        case "bmp": return "checkerboard.rectangle"
        default: return "doc.fill"
        }
    }
    
    private var savingsText: String {
        switch file.status {
        case .done:
            return String(format: "-%.0f%%", file.savingsPercent * 100)
        case .skipped:
            return NSLocalizedString("Skip", comment: "")
        case .error:
            return NSLocalizedString("Error", comment: "")
        case .pending:
            return NSLocalizedString("Pending", comment: "")
        default:
            return ""
        }
    }
}
