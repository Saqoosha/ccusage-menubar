import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject var usageManager: UsageManager
    
    var body: some View {
        HStack(spacing: 4) {
            // Claude icon
            Image(systemName: "brain.head.profile")
                .foregroundColor(.primary)
            
            // Cost display
            if usageManager.isLoading {
                Text("...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if let todayCost = usageManager.todayCost {
                Text(formatCost(todayCost))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            } else {
                Text("--")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return "$0.00"
        } else if cost < 1.0 {
            return String(format: "$%.2f", cost)
        } else if cost < 100.0 {
            return String(format: "$%.1f", cost)
        } else {
            return String(format: "$%.0f", cost)
        }
    }
}