import SwiftUI

// MARK: - Layout Utilities

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(
            EdgeBorder(width: width, edges: edges).foregroundColor(color)
        )
    }
}

// MARK: - Pro Theme Colors

extension Color {
    static let proBg = Color(nsColor: NSColor(name: "proBg", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.12, alpha: 1.0) : NSColor(white: 0.93, alpha: 1.0)
    }))
    
    static let proPanel = Color(nsColor: NSColor(name: "proPanel", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.145, alpha: 1.0) : NSColor(white: 1.0, alpha: 1.0)
    }))
    
    static let proBorder = Color(nsColor: NSColor(name: "proBorder", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.2, alpha: 1.0) : NSColor(white: 0.85, alpha: 1.0)
    }))
    
    static let proTextMain = Color(nsColor: NSColor(name: "proTextMain", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.8, alpha: 1.0) : NSColor(white: 0.2, alpha: 1.0)
    }))
    
    // Increased contrast for Dark Mode (0.52 -> 0.70)
    static let proTextMuted = Color(nsColor: NSColor(name: "proTextMuted", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.70, alpha: 1.0) : NSColor(white: 0.5, alpha: 1.0)
    }))
    
    static let proToolbar = Color(nsColor: NSColor(name: "proToolbar", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.18, alpha: 1.0) : NSColor(white: 1.0, alpha: 1.0)
    }))
    
    static let proBtnActive = Color(nsColor: NSColor(name: "proBtnActive", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.90, alpha: 1.0)
    }))
    
    static let proAccent = Color(red: 14/255, green: 99/255, blue: 156/255)
    static let proGreen = Color(red: 76/255, green: 175/255, blue: 80/255)
}
