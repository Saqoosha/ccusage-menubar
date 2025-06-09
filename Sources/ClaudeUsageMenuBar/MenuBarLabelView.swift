import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject var usageManager: UsageManager
    
    var body: some View {
        // Cost display - always show value if available, even while loading
        if let todayCost = usageManager.todayCost {
            Text(formatCost(todayCost))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        } else if usageManager.isLoading {
            // Only show loading state if no previous value exists
            Text("...")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        } else {
            Text("--")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }
}