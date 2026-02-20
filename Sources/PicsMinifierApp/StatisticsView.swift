import SwiftUI
import PicsMinifierCore

struct StatisticsView: View {
    @Bindable var settingsStore: SettingsStore
    var sessionStore: SessionStore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text(NSLocalizedString("Statistics", comment: ""))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.proTextMain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Session Stats
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: NSLocalizedString("CURRENT SESSION", comment: ""), icon: "clock.fill")
                    
                    StatsGrid {
                        StatCard(title: NSLocalizedString("Processed", comment: ""), value: "\(sessionStore.sessionCompressedCount)", icon: "doc.text.fill", color: .blue)
                        StatCard(title: NSLocalizedString("Saved", comment: ""), value: ByteCountFormatter.string(fromByteCount: Int64(sessionStore.sessionSavedBytes), countStyle: .file), icon: "leaf.fill", color: .green)
                    }
                }
                .padding(.horizontal, 16)
                
                // Lifetime Stats
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: NSLocalizedString("LIFETIME SAVINGS", comment: ""), icon: "infinity")
                    
                    StatsGrid {
                        StatCard(title: NSLocalizedString("Total Files", comment: ""), value: "\(settingsStore.lifetimeCompressedCount)", icon: "folder.fill", color: .purple)
                        StatCard(title: NSLocalizedString("Total Saved", comment: ""), value: ByteCountFormatter.string(fromByteCount: Int64(settingsStore.lifetimeSavedBytes), countStyle: .file), icon: "chart.line.uptrend.xyaxis", color: .orange)
                    }
                }
                .padding(.horizontal, 16)
                
                // Format Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: NSLocalizedString("BY FORMAT", comment: ""), icon: "list.bullet.rectangle.fill")
                    
                    VStack(spacing: 1) {
                        let data = settingsStore.formatSavings.sorted(by: { $0.value > $1.value })
                        if data.isEmpty {
                            Text(NSLocalizedString("No data yet", comment: ""))
                                .font(.caption)
                                .foregroundStyle(Color.proTextMuted)
                                .padding()
                        } else {
                            ForEach(data, id: \.key) { format, saved in
                                FormatSavingsRow(format: format, saved: saved)
                            }
                        }
                    }
                    .background(Color.proControlBg)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.proControlBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                
                // Privacy Setting
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: NSLocalizedString("PRIVACY", comment: ""), icon: "lock.shield.fill")
                    
                    ProToggle(isOn: $settingsStore.disableStatistics, title: NSLocalizedString("Disable Statistics", comment: ""), icon: "nosign")
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
        .background(Color.proBg)
    }
}

struct StatsGrid<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        HStack(spacing: 12) {
            content
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14))
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.proTextMain)
            
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.proTextMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.proControlBg)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.proControlBorder, lineWidth: 1)
        )
    }
}

struct FormatSavingsRow: View {
    let format: String
    let saved: Int
    
    var body: some View {
        HStack {
            Text(".\(format.uppercased())")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.proTextMain)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: Int64(saved), countStyle: .file))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.proGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
