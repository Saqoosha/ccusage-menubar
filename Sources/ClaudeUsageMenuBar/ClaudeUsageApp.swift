import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var usageManager = UsageManager()
    
    var body: some Scene {
        // Modern MenuBarExtra approach - no main window needed
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(usageManager)
        } label: {
            MenuBarLabelView()
                .environmentObject(usageManager)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window (optional)
        Settings {
            SettingsView()
                .environmentObject(usageManager)
        }
    }
}