import Foundation

/// Cost calculation mode that determines how costs are calculated from usage data
enum CostMode: String, CaseIterable {
    /// Automatically selects the best available method: uses pre-calculated costUSD if available, otherwise calculates from tokens
    case auto = "auto"
    
    /// Always calculates costs from token counts using current pricing, ignoring any pre-calculated costUSD values
    case calculate = "calculate"
    
    /// Only uses pre-calculated costUSD values, showing 0 if not available
    case display = "display"
    
    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .calculate:
            return "Calculate"
        case .display:
            return "Display"
        }
    }
    
    var description: String {
        switch self {
        case .auto:
            return "Use costUSD if available, otherwise calculate"
        case .calculate:
            return "Always calculate from current pricing"
        case .display:
            return "Only use pre-calculated costs"
        }
    }
}