import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var usageManager: UsageManager
    @State private var selectedInterval: Int = Int(UserDefaults.standard.double(forKey: "refreshInterval")) > 0 
        ? Int(UserDefaults.standard.double(forKey: "refreshInterval")) 
        : 60
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Update Interval") {
                    Picker("Refresh every", selection: $selectedInterval) {
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedInterval) { newValue in
                        usageManager.updateRefreshInterval(TimeInterval(newValue))
                    }
                }
                
                Section("Display") {
                    Toggle("Show cost in menu bar", isOn: .constant(true))
                    Toggle("Show token counts", isOn: .constant(true))
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("GitHub Repository", destination: URL(string: "https://github.com/saqoosha/claude-usage-menubar")!)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}