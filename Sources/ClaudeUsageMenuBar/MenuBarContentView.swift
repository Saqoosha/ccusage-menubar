import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var usageManager: UsageManager
    @State private var isRefreshing = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("Claude Code Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatCount(isRefreshing ? 100 : 1, autoreverses: false), value: isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
            
            Divider()
            
            // Today's usage
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Input: \(formatTokens(usageManager.todayInputTokens))")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Output: \(formatTokens(usageManager.todayOutputTokens))")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(formatCost(usageManager.todayCost ?? 0))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Divider()
            
            // This month's usage
            VStack(alignment: .leading, spacing: 8) {
                Text("This Month")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Input: \(formatTokens(usageManager.monthInputTokens))")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Output: \(formatTokens(usageManager.monthOutputTokens))")
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(formatCost(usageManager.monthCost ?? 0))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Divider()
            
            // Last updated
            HStack {
                Text("Last updated: \(formatLastUpdated())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Settings button
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                // Quit button
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
            }
        }
        .padding()
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
    
    private func openSettings() {
        showingSettings = true
        
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Claude Usage Settings"
        settingsWindow.center()
        settingsWindow.contentView = NSHostingView(
            rootView: SettingsView()
                .environmentObject(usageManager)
        )
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}