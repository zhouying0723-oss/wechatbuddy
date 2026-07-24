import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("WeChatBuddy")

        Text("状态：\(appState.status.title)")

        Divider()

        Button("打开设置…") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        Button("退出 WeChatBuddy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
