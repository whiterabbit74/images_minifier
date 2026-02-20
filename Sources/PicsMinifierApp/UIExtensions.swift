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
    static var proBg: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.12, alpha: 1.0)
            } else {
                // Soft Silk White for premium Light Mode
                return NSColor(deviceRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
            }
        }))
    }
    
    static var proPanel: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.145, alpha: 1.0)
            } else {
                // Clean White for panels
                return NSColor.white
            }
        }))
    }
    
    static var proBorder: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.2, alpha: 1.0)
            } else {
                // Subtle gray border
                return NSColor(white: 0.92, alpha: 1.0)
            }
        }))
    }
    
    static var proTextMain: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.9, alpha: 1.0)
            } else {
                // Deep Navy/Charcoal for text
                return NSColor(deviceRed: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
            }
        }))
    }
    
    static var proTextMuted: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.65, alpha: 1.0)
            } else {
                // Soft muted gray
                return NSColor(white: 0.5, alpha: 1.0)
            }
        }))
    }
    
    static var proToolbar: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.18, alpha: 1.0)
            } else {
                return NSColor(white: 1.0, alpha: 1.0)
            }
        }))
    }
    
    static var proBtnActive: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.22, alpha: 1.0)
            } else {
                return NSColor(white: 0.95, alpha: 1.0)
            }
        }))
    }

    static var proControlBg: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.18, alpha: 1.0)
            } else {
                // Slightly elevated surface for light mode
                return NSColor(white: 0.97, alpha: 1.0)
            }
        }))
    }

    static var proControlBorder: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.25, alpha: 1.0)
            } else {
                return NSColor(white: 0.93, alpha: 1.0)
            }
        }))
    }

    static var proHeaderBg: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.12, alpha: 1.0)
            } else {
                return NSColor(white: 0.99, alpha: 1.0)
            }
        }))
    }

    static var proHover: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.17, alpha: 1.0)
            } else {
                return NSColor(white: 0.94, alpha: 1.0)
            }
        }))
    }
    
    static var proAccent: Color { Color(red: 14/255, green: 99/255, blue: 156/255) }
    static var proGreen: Color { Color(red: 46/255, green: 165/255, blue: 80/255) }
    static var proOrange: Color { Color(red: 255/255, green: 140/255, blue: 0/255) }
    static var proPurple: Color { Color(red: 136/255, green: 39/255, blue: 176/255) }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Common UI Components

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.proTextMuted)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.proTextMuted)
        }
        .padding(.bottom, 4)
    }
}

struct ProToggle: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.proTextMain)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .padding(12)
        .background(Color.proControlBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.proControlBorder, lineWidth: 1)
        )
    }
}
// MARK: - Premium Materials

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .followsWindowActiveState

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

extension View {
    func glossyMaterial(_ material: NSVisualEffectView.Material = .sidebar) -> some View {
        background(VisualEffectView(material: material))
    }
}
