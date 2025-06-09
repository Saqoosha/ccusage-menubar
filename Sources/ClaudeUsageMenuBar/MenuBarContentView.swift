import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var usageManager: UsageManager
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Today's usage - modern card style
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text("Today")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCost(usageManager.todayCost ?? 0))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Input")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatTokens(usageManager.todayInputTokens))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatTokens(usageManager.todayOutputTokens))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 2)
            
            Divider()
            
            // This month's usage - modern card style
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text("This Month")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatCost(usageManager.monthCost ?? 0))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Input")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatTokens(usageManager.monthInputTokens))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatTokens(usageManager.monthOutputTokens))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 2)
            
            // Future: Chart section will go here
            // if showChart {
            //     Divider()
            //     ChartView()
            //         .frame(height: 120)
            // }
            
            Divider()
            
            // Footer with controls
            HStack {
                HStack(spacing: 4) {
                    Text("Updated \(formatLastUpdated())")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Button {
                        refresh()
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatCount(isRefreshing ? 100 : 1, autoreverses: false), value: isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isRefreshing)
                    .help("Refresh usage data")
                }
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    private func formatCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }
    
    private func formatLastUpdated() -> String {
        guard let lastUpdate = usageManager.lastUpdated else {
            return "Never"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdate)
    }
    
    private func refresh() {
        isRefreshing = true
        Task {
            await usageManager.refreshUsage()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}