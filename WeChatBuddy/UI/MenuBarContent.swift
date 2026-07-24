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

        Text("快捷键：\(appState.hotKeyStatus.title)")

        Text(appState.draftReadStatus.title)

        Text(appState.draftWriteStatus.title)

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
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                presentDraftReadResult(appState.readWeChatDraft())
            }
        }

        Button("测试写回微信输入框") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                presentDraftWriteResult(appState.testWriteWeChatDraft())
            }
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

    private func presentDraftReadResult(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "微信输入框读取结果"
        alert.informativeText = message
        alert.alertStyle = message.hasPrefix("读取成功") ? .informational : .warning
        alert.addButton(withTitle: "确定")

        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentDraftWriteResult(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "微信输入框写回结果"
        alert.informativeText = message
        alert.alertStyle = message.hasPrefix("写回成功") ? .informational : .warning
        alert.addButton(withTitle: "确定")

        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
