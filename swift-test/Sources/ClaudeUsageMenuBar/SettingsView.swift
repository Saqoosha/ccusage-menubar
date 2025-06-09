import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var usageManager: UsageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Update Interval") {
                    Picker("Refresh every", selection: .constant(5)) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("30 minutes").tag(30)
                    }
                    .pickerStyle(.menu)
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