import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject var usageManager: UsageManager
    @StateObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        // Cost display - always show value if available, even while loading
        if let todayCost = usageManager.todayCost {
            Text(currencyManager.formatCurrency(todayCost))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
}