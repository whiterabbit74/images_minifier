
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("File")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                
                Text("Original")
                    .frame(width: 100, alignment: .trailing)
                
                Text("Optimized")
                    .frame(width: 100, alignment: .trailing)
                
                Text("Savings")
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
                let totalOriginal = files.reduce(0) { $0 + $1.originalSize }
                let totalOptimized = files.reduce(0) { $0 + $1.optimizedSize }
                let totalSaved = max(0, totalOriginal - totalOptimized)
                let percent = totalOriginal > 0 ? Double(totalSaved) / Double(totalOriginal) * 100 : 0
                
                HStack {
                    Text("\(files.count) Files processed successfully")
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Saved")
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
        case "png": return "desktopcomputer" // screenshot_cover.png shows a monitor
        case "jpg", "jpeg": return "camera.fill" // photo_session_01.jpg shows a camera
        case "svg": return "paintpalette.fill" // logo_vector.svg shows a palette
        case "gif": return "film.fill" // animation.gif shows a film reel
        default: return "doc.fill"
        }
    }
    
    private var savingsText: String {
        switch file.status {
        case .done:
            return String(format: "-%.0f%%", file.savingsPercent * 100)
        case .skipped:
            return "Skip"
        case .error:
            return "Error"
        default:
            return ""
        }
    }
}
