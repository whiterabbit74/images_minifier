
import SwiftUI

enum InterfaceMode: String, CaseIterable {
    case dock
    case both
    case menuBar
}

struct InterfaceModeButton: View {
    let mode: InterfaceMode
    let current: InterfaceMode
    let icon: String
    let title: String
    let action: () -> Void

    var isSelected: Bool { mode == current }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
