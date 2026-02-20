
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
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.proTextMuted)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.proTextMain : Color.proTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
