import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("设置功能将在后续阶段提供。")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420, height: 180)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
