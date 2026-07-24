import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("WeChatBuddy")

        Text("状态：\(appState.status.title)")

        Text("辅助功能：\(appState.accessibilityStatus.title)")

        Text("微信前台：\(appState.weChatFrontmostStatus.title)")

        Text("检测应用：\(appState.detectedFrontmostBundleIdentifier ?? "未知")")

        Text(appState.draftReadStatus.title)

        if appState.accessibilityStatus == .notAuthorized {
            Button("请求辅助功能权限") {
                appState.requestAccessibilityAccess()
            }

            Button("打开辅助功能设置…") {
                appState.openAccessibilitySettings()
            }
        }

        Divider()

        Button("读取微信输入框") {
            appState.readWeChatDraft()
        }

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
        .onAppear {
            appState.refreshAccessibilityStatus()
            appState.refreshWeChatFrontmostStatus()
        }
    }
}
